-- =====================================================================
-- RECON v1 · 04 · Score history + pipeline events
-- Run AFTER 03_v1_audit_score_trail.sql, in the Neon SQL Editor.
--
-- Why: a reset + rescore used to overwrite the old score with no trace.
--   * score_history   one row per score ever given, never edited/deleted
--                     (filled by a trigger, so no n8n node changes needed)
--   * pipeline_events one row per run or operator action (score runs,
--                     resets, later: resolve runs), never edited/deleted
--   * reset_scores()  the ONLY way to reset: refuses leads that already
--                     have a review decision, and logs itself
-- =====================================================================
BEGIN;

-- 1) Score history: every score a lead has ever had, with its reasons.
CREATE TABLE IF NOT EXISTS score_history (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lead_key         TEXT        NOT NULL REFERENCES leads_master(lead_key),
  rubric_version   TEXT,
  opportunity_pts  SMALLINT,
  viability_pts    SMALLINT,
  final_score      SMALLINT,
  tier             TEXT,
  tags             TEXT[],
  score_reasons    JSONB,
  scored_at        TIMESTAMPTZ NOT NULL,
  recorded_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_score_history_lead ON score_history (lead_key, scored_at);

-- 2) Pipeline events: what ran or what was done, how many leads, and why.
CREATE TABLE IF NOT EXISTS pipeline_events (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event            TEXT        NOT NULL,   -- score_run | reset_scores | resolve_run | ...
  rubric_version   TEXT,
  leads_affected   INTEGER     NOT NULL DEFAULT 0,
  lead_keys        TEXT[]      NOT NULL DEFAULT '{}',
  reason           TEXT,
  actor            TEXT        NOT NULL DEFAULT 'workflow',  -- workflow | operator
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pipeline_events_time ON pipeline_events (created_at);

-- Both tables are append-only, same rule as lead_decisions.
CREATE OR REPLACE FUNCTION block_log_changes() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION '% is append-only: % is not allowed', TG_TABLE_NAME, TG_OP;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_score_history_append_only ON score_history;
CREATE TRIGGER trg_score_history_append_only
  BEFORE UPDATE OR DELETE ON score_history
  FOR EACH ROW EXECUTE FUNCTION block_log_changes();

DROP TRIGGER IF EXISTS trg_pipeline_events_append_only ON pipeline_events;
CREATE TRIGGER trg_pipeline_events_append_only
  BEFORE UPDATE OR DELETE ON pipeline_events
  FOR EACH ROW EXECUTE FUNCTION block_log_changes();

-- 3) Every time Save Score writes a new score, copy it into history.
CREATE OR REPLACE FUNCTION record_score_history() RETURNS trigger AS $$
BEGIN
  IF NEW.scored_at IS NOT NULL
     AND NEW.scored_at IS DISTINCT FROM OLD.scored_at THEN
    INSERT INTO score_history (lead_key, rubric_version, opportunity_pts, viability_pts,
                               final_score, tier, tags, score_reasons, scored_at)
    VALUES (NEW.lead_key, NEW.rubric_version, NEW.opportunity_pts, NEW.viability_pts,
            NEW.final_score, NEW.tier, NEW.tags, NEW.score_reasons, NEW.scored_at);
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_leads_score_history ON leads_master;
CREATE TRIGGER trg_leads_score_history
  AFTER UPDATE OF scored_at ON leads_master
  FOR EACH ROW EXECUTE FUNCTION record_score_history();

-- 4) The reset. Usage:
--    SELECT * FROM reset_scores('why you are resetting', 'v0.2');
--    Leads with any review decision are skipped and never reset.
CREATE OR REPLACE FUNCTION reset_scores(p_reason TEXT, p_rubric TEXT DEFAULT NULL)
RETURNS TABLE (lead_key TEXT, business_name TEXT) AS $$
DECLARE
  v_keys TEXT[];
BEGIN
  IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reset_scores needs a reason';
  END IF;

  WITH r AS (
    UPDATE leads_master m
    SET automation_status = 'audited'
    WHERE m.automation_status = 'scored'
      AND NOT EXISTS (SELECT 1 FROM lead_decisions d WHERE d.lead_key = m.lead_key)
    RETURNING m.lead_key
  )
  SELECT coalesce(array_agg(r.lead_key), '{}') INTO v_keys FROM r;

  INSERT INTO pipeline_events (event, rubric_version, leads_affected, lead_keys, reason, actor)
  VALUES ('reset_scores', p_rubric, cardinality(v_keys), v_keys, p_reason, 'operator');

  RETURN QUERY
    SELECT m.lead_key, m.business_name FROM leads_master m
    WHERE m.lead_key = ANY (v_keys);
END; $$ LANGUAGE plpgsql;

-- 6) Seed history with the scores that exist right now, as the v0.2 baseline.
INSERT INTO score_history (lead_key, rubric_version, opportunity_pts, viability_pts,
                           final_score, tier, tags, score_reasons, scored_at)
SELECT lead_key, rubric_version, opportunity_pts, viability_pts,
       final_score, tier, tags, score_reasons, scored_at
FROM leads_master m
WHERE scored_at IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM score_history h
                  WHERE h.lead_key = m.lead_key AND h.scored_at = m.scored_at);

COMMIT;

-- ===== CHECK (run after) =====
-- SELECT event, leads_affected, reason, created_at FROM pipeline_events ORDER BY id;
--   expect 0 rows on a fresh install
-- SELECT count(*) FROM score_history;
--   expect = number of leads scored so far
-- SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_%history%' OR tgname LIKE 'trg_pipeline%';
--   expect 3 triggers
-- SELECT automation_status, count(*) FROM leads_master GROUP BY 1 ORDER BY 1;
