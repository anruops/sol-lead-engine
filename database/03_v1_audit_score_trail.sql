-- ============================================================================
-- RECON — Migration 03 · v1 lead record, audit, score and paper trail
-- ----------------------------------------------------------------------------
-- Adds what RECON v1 (one canvas: Mining → Refinery → Audit → Score →
-- Review Gate) needs, per docs/RECON-v1-Anatomy.docx:
--   * Lead record columns produced by the Normalize node (map source)
--   * Audit columns (what a frustrated customer runs into on the website)
--   * Score columns (Opportunity + Viability = Final /100, tier, tags)
--   * New lifecycle states, including 'excluded' (chains, closed, off-niche)
--   * lead_decisions: APPEND-ONLY paper trail (updates/deletes are blocked)
--   * mining_runs: one row per mining run
--
-- Additive only: nothing existing is dropped or renamed. Safe to re-run.
-- Run AFTER 01 and 02, in the Neon SQL Editor, in TWO steps:
--   STEP 1 = the ALTER TYPE lines (cannot run inside a transaction)
--   STEP 2 = everything from BEGIN to COMMIT
-- ============================================================================


-- ===== STEP 1 · new lifecycle states (run on their own) =====================
ALTER TYPE lead_state ADD VALUE IF NOT EXISTS 'excluded';   -- chain / closed / off-niche / no name
ALTER TYPE lead_state ADD VALUE IF NOT EXISTS 'audited';    -- website audit done
ALTER TYPE lead_state ADD VALUE IF NOT EXISTS 'in_review';  -- card sent, waiting on the reviewer
ALTER TYPE lead_state ADD VALUE IF NOT EXISTS 'approved';
ALTER TYPE lead_state ADD VALUE IF NOT EXISTS 'rejected';
ALTER TYPE lead_state ADD VALUE IF NOT EXISTS 'snoozed';


-- ===== STEP 2 · columns, tables, guards =====================================
BEGIN;

-- 1) Lead record (from Normalize). Existing columns reused, not duplicated:
--    niche → target_niche, city → city, country → country,
--    website → website_url, raw score reasons → score_reasons.
ALTER TABLE leads_master
  ADD COLUMN IF NOT EXISTS source           TEXT,                -- 'osm' (others later)
  ADD COLUMN IF NOT EXISTS source_id        TEXT,                -- e.g. 'node/599493144'
  ADD COLUMN IF NOT EXISTS business_name    TEXT,
  ADD COLUMN IF NOT EXISTS address          TEXT,
  ADD COLUMN IF NOT EXISTS region           TEXT,                -- state / county
  ADD COLUMN IF NOT EXISTS postcode         TEXT,
  ADD COLUMN IF NOT EXISTS lat              DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS lon              DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS phone            TEXT,
  ADD COLUMN IF NOT EXISTS website_domain   TEXT,
  ADD COLUMN IF NOT EXISTS email            TEXT,                -- as found; verified_email stays for verified only
  ADD COLUMN IF NOT EXISTS email_type       TEXT,                -- business | freemail | other
  ADD COLUMN IF NOT EXISTS socials          JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS opening_hours    TEXT,
  ADD COLUMN IF NOT EXISTS osm_last_edit    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS brand            TEXT,
  ADD COLUMN IF NOT EXISTS multi_location   BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS location_count   SMALLINT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS exclude_reason   TEXT,                -- chain | closed | off_niche | no_name
  ADD COLUMN IF NOT EXISTS raw_tags         JSONB;               -- untouched source data, for the trail

-- 2) Audit (Lane 3).
ALTER TABLE leads_master
  ADD COLUMN IF NOT EXISTS site_status      TEXT,                -- none | ok | down | redirect | error
  ADD COLUMN IF NOT EXISTS final_url        TEXT,                -- where the website actually landed
  ADD COLUMN IF NOT EXISTS https            BOOLEAN,
  ADD COLUMN IF NOT EXISTS mobile_ready     BOOLEAN,
  ADD COLUMN IF NOT EXISTS copyright_year   SMALLINT,
  ADD COLUMN IF NOT EXISTS has_booking      BOOLEAN,
  ADD COLUMN IF NOT EXISTS booking_provider TEXT,
  ADD COLUMN IF NOT EXISTS has_contact_form BOOLEAN,
  ADD COLUMN IF NOT EXISTS emails_found     TEXT[],
  ADD COLUMN IF NOT EXISTS company_status   TEXT,                -- UK Companies House (wave 2)
  ADD COLUMN IF NOT EXISTS audited_at       TIMESTAMPTZ;

-- 3) Score (Lane 4). Final = Opportunity (≤70) + Viability (≤30).
ALTER TABLE leads_master
  ADD COLUMN IF NOT EXISTS opportunity_pts  SMALLINT,
  ADD COLUMN IF NOT EXISTS viability_pts    SMALLINT,
  ADD COLUMN IF NOT EXISTS final_score      SMALLINT CHECK (final_score BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS tier             TEXT,                -- hot | warm | cold | check_alive
  ADD COLUMN IF NOT EXISTS tags             TEXT[] NOT NULL DEFAULT '{}',  -- growth_prospect, needs_check, ...
  ADD COLUMN IF NOT EXISTS rubric_version   TEXT,
  ADD COLUMN IF NOT EXISTS scored_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS contact_route    TEXT,                -- email | phone | contact_form | visit
  ADD COLUMN IF NOT EXISTS email_allowed    BOOLEAN,
  ADD COLUMN IF NOT EXISTS snooze_until     TIMESTAMPTZ;

-- 4) Paper trail: one row per decision, never edited, never deleted.
CREATE TABLE IF NOT EXISTS lead_decisions (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lead_key        TEXT        NOT NULL REFERENCES leads_master(lead_key),
  decision        TEXT        NOT NULL,      -- approve | reject | snooze (v2: email_sent, replied, ...)
  final_score     SMALLINT,                  -- snapshot at the moment of deciding
  tier            TEXT,
  score_reasons   JSONB,
  rubric_version  TEXT,
  note            TEXT,                      -- the reviewer's read, optional
  decided_via     TEXT        NOT NULL,      -- telegram | slack | manual
  decided_by      TEXT        NOT NULL,
  decided_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_decisions_lead ON lead_decisions (lead_key, decided_at);

CREATE OR REPLACE FUNCTION block_decision_changes() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'lead_decisions is append-only: % is not allowed', TG_OP;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_lead_decisions_append_only ON lead_decisions;
CREATE TRIGGER trg_lead_decisions_append_only
  BEFORE UPDATE OR DELETE ON lead_decisions
  FOR EACH ROW EXECUTE FUNCTION block_decision_changes();

-- 5) Mining runs: what was searched, how much came back, which server answered.
CREATE TABLE IF NOT EXISTS mining_runs (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_batch  TEXT        NOT NULL,
  city          TEXT        NOT NULL,
  niche         TEXT        NOT NULL,
  endpoint      TEXT,                        -- main | mirror
  found         INTEGER     NOT NULL DEFAULT 0,
  new_leads     INTEGER     NOT NULL DEFAULT 0,
  excluded      INTEGER     NOT NULL DEFAULT 0,
  started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at   TIMESTAMPTZ
);

-- 6) Indexes for the competitor query and the review queue.
CREATE INDEX IF NOT EXISTS idx_leads_niche_geo  ON leads_master (target_niche, lat, lon);
CREATE INDEX IF NOT EXISTS idx_leads_source     ON leads_master (source, source_id);
CREATE INDEX IF NOT EXISTS idx_leads_tier       ON leads_master (tier);

COMMIT;

-- ===== CHECK (run after, expect: 6 states added, 2 new tables, trigger) =====
-- SELECT unnest(enum_range(NULL::lead_state));
-- SELECT table_name FROM information_schema.tables
--  WHERE table_name IN ('lead_decisions','mining_runs');
-- SELECT tgname FROM pg_trigger WHERE tgname = 'trg_lead_decisions_append_only';
