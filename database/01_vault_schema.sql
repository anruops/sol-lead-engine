-- ============================================================================
-- RECON — The Vault (leads_master) + supporting tables
-- Target: self-hosted Postgres that n8n reads/writes. Niche-agnostic.
-- ----------------------------------------------------------------------------
-- Design notes (from the Build Guide + Knowledge Base):
--   * Every parameter is its own column so priority is queryable directly, e.g.
--       SELECT * FROM leads_master WHERE quality_score > 8 AND industry = 'Hospitality';
--   * Idempotency: upsert on a STABLE key (lead_key) so re-runs update in place.
--   * The Synched bug fix lives in the Refinery workflow, but the column is here:
--       synched defaults FALSE; Refinery must set it TRUE *on success only*.
--   * Supporting tables: suppression_list (unsubscribe), review_queue (loud
--     failures / low-confidence), email_log (per-lead send state, idempotent),
--     reply_labels (labelled set to validate the Brain pass-2 classifier).
-- Run once:  psql "$DATABASE_URL" -f 01_vault_schema.sql
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS public;

-- Enums keep bands/states typo-proof (the HITL dropdown equivalent, in DB form).
DO $$ BEGIN
  CREATE TYPE priority_band AS ENUM ('High', 'Medium', 'Low', 'Unscored');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  -- The lead's position in its lifecycle. RECON ends at 'converted' (handoff to LUNA).
  CREATE TYPE lead_state AS ENUM (
    'new',          -- landed in the vault, unscored
    'scored',       -- Brain pass 1 done
    'contacted',    -- first outreach sent
    'warming',      -- in the 3-strike warm-up
    'replied',      -- inbound reply received
    'junk',         -- 3 strikes, no signs of life -> To-Be-Sold
    'converted'     -- won; handed to LUNA, RECON stops
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE reply_class AS ENUM (
    'interested', 'not_interested', 'objection', 'auto_responder',
    'gibberish', 'no_reply', 'unclassified'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ----------------------------------------------------------------------------
-- leads_master — the permanent vault. The dashboard reads off this.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS leads_master (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- Stable upsert key: lower(verified_email) else normalized website domain.
  -- Refinery computes it; UNIQUE so re-runs update in place, never duplicate.
  lead_key          TEXT        NOT NULL,

  -- ---- Captured data fields (Build Guide) --------------------------------
  owner_name        TEXT,
  target_niche      TEXT,
  product_service   TEXT,
  ideal_partner_type TEXT,
  company_type      TEXT,                 -- startup / enterprise / ...
  company_size      TEXT,
  industry          TEXT,
  job_title         TEXT,                 -- decision-maker role
  city              TEXT,
  country           TEXT,
  source_link       TEXT,                 -- where the lead was found
  website_url       TEXT,
  verified_email    TEXT,
  linkedin_url      TEXT,
  personalized_hook TEXT,                 -- AI-generated, analysed only on provided data

  -- ---- Scoring rubric parameters (stored individually so they're queryable) -
  profession        TEXT,
  primary_services  TEXT,
  secondary_services TEXT,
  service_keywords  TEXT,
  target_client     TEXT,
  pain_points       TEXT,
  intent_signals    TEXT,
  urgency_indicators TEXT,
  price_points      TEXT,

  -- ---- Scores & lifecycle ------------------------------------------------
  quality_score     NUMERIC(3,1),         -- Brain pass 1, 1.0 - 10.0
  priority          priority_band NOT NULL DEFAULT 'Unscored',
  score_reasons     JSONB,                -- per-factor breakdown from the rubric
  reply_score       NUMERIC(3,1),         -- Brain pass 2 (advisory until promoted)
  reply_class       reply_class   NOT NULL DEFAULT 'unclassified',

  automation_status lead_state    NOT NULL DEFAULT 'new',
  warmup_count      SMALLINT      NOT NULL DEFAULT 0,     -- 3-strike rule
  last_contacted_at TIMESTAMPTZ,
  converted_at      TIMESTAMPTZ,
  deal_amount       NUMERIC(12,2),                         -- optional; LUNA owns billing
  handed_to_luna    BOOLEAN       NOT NULL DEFAULT FALSE, -- one handoff, fire-once guard

  -- ---- Plumbing ----------------------------------------------------------
  synched           BOOLEAN       NOT NULL DEFAULT FALSE, -- set TRUE on success ONLY
  source_batch      TEXT,                                 -- which scrape/intake run
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- The stable key is what upsert matches on.
DO $$ BEGIN
  ALTER TABLE leads_master ADD CONSTRAINT leads_master_lead_key_uq UNIQUE (lead_key);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Keep updated_at honest on every write.
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_leads_master_updated ON leads_master;
CREATE TRIGGER trg_leads_master_updated
  BEFORE UPDATE ON leads_master
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes for the dashboard's hot queries.
CREATE INDEX IF NOT EXISTS idx_leads_priority      ON leads_master (priority);
CREATE INDEX IF NOT EXISTS idx_leads_state         ON leads_master (automation_status);
CREATE INDEX IF NOT EXISTS idx_leads_industry      ON leads_master (industry);
CREATE INDEX IF NOT EXISTS idx_leads_unscored      ON leads_master (quality_score) WHERE quality_score IS NULL;
CREATE INDEX IF NOT EXISTS idx_leads_last_contact  ON leads_master (last_contacted_at);
CREATE INDEX IF NOT EXISTS idx_leads_not_synched   ON leads_master (synched) WHERE synched = FALSE;

-- ----------------------------------------------------------------------------
-- suppression_list — the mandatory unsubscribe / do-not-contact register.
-- Email module checks this BEFORE every send.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS suppression_list (
  email        TEXT PRIMARY KEY,          -- stored lower-cased
  reason       TEXT,                      -- 'unsubscribe' | 'bounce' | 'complaint' | 'manual'
  added_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- email_log — per-lead, per-step send state. Makes outreach idempotent:
-- never email the same lead the same step twice.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS email_log (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lead_key     TEXT NOT NULL REFERENCES leads_master(lead_key) ON DELETE CASCADE,
  step         TEXT NOT NULL,             -- 'outreach_1' | 'warmup_2' | 'warmup_3' | ...
  direction    TEXT NOT NULL DEFAULT 'outbound',  -- outbound | inbound
  subject      TEXT,
  gmail_message_id TEXT,
  sent_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lead_key, step, direction)
);
CREATE INDEX IF NOT EXISTS idx_email_log_lead ON email_log (lead_key);

-- ----------------------------------------------------------------------------
-- review_queue — loud-failure sink. Anything empty / low-confidence / filtered
-- lands here with its input and reason, then an alert fires. (Knowledge Base.)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS review_queue (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  stage        TEXT NOT NULL,             -- 'mining' | 'refinery' | 'brain1' | 'email' | ...
  reason       TEXT NOT NULL,
  payload      JSONB,                     -- the offending input, verbatim
  status       TEXT NOT NULL DEFAULT 'pending',  -- pending | approved | discarded
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_review_status ON review_queue (status);

-- ----------------------------------------------------------------------------
-- reply_labels — labelled set to validate Brain pass 2 before it's promoted
-- from advisory to acting. Feed it synthetic + real replies, correct, learn.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reply_labels (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lead_key       TEXT,
  reply_text     TEXT NOT NULL,
  predicted      reply_class,             -- what the classifier said
  corrected      reply_class,             -- what a human says it actually is
  is_synthetic   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;

-- ============================================================================
-- Handy views for the dashboard (read-only surface over leads_master).
-- ============================================================================
CREATE OR REPLACE VIEW v_pipeline_by_priority AS
  SELECT priority, count(*) AS leads
  FROM leads_master
  WHERE automation_status <> 'junk'
  GROUP BY priority;

-- Anti-decay flag: High/Medium leads not contacted in 48h.
CREATE OR REPLACE VIEW v_stale_leads AS
  SELECT id, lead_key, owner_name, industry, priority, last_contacted_at
  FROM leads_master
  WHERE priority IN ('High','Medium')
    AND automation_status IN ('scored','contacted','warming')
    AND (last_contacted_at IS NULL OR last_contacted_at < now() - interval '48 hours');

CREATE OR REPLACE VIEW v_reply_mix AS
  SELECT reply_class, count(*) AS n
  FROM leads_master
  WHERE reply_class <> 'unclassified'
  GROUP BY reply_class;

-- Conversion rate = converted / everything that entered outreach.
CREATE OR REPLACE VIEW v_conversion AS
  SELECT
    count(*) FILTER (WHERE automation_status = 'converted')                          AS converted,
    count(*) FILTER (WHERE automation_status IN ('contacted','warming','replied','converted')) AS contacted,
    ROUND(
      100.0 * count(*) FILTER (WHERE automation_status = 'converted')
      / NULLIF(count(*) FILTER (WHERE automation_status IN ('contacted','warming','replied','converted')),0)
    , 1) AS conversion_pct
  FROM leads_master;

-- Inventory on hand: verified, scored leads not yet contacted.
CREATE OR REPLACE VIEW v_inventory AS
  SELECT priority, count(*) AS ready
  FROM leads_master
  WHERE verified_email IS NOT NULL
    AND automation_status = 'scored'
  GROUP BY priority;
