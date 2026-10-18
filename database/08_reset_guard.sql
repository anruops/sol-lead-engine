-- =====================================================================
-- RECON v1 · 08 · Reset guard: only final decisions protect a lead
-- Run AFTER 07 (summarized_at), in the Neon SQL Editor.
--
-- Why: reset_scores() skipped any lead with ANY decision. But add_website
-- and confirm_no_site are data corrections, not verdicts, so leads that
-- were corrected never got rescored (found in the v0.3 calibration).
-- Now only approve / reject / snooze / closed protect a lead from resets.
-- =====================================================================
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
    SET automation_status = 'audited', summarized_at = NULL
    WHERE m.automation_status = 'scored'
      AND NOT EXISTS (SELECT 1 FROM lead_decisions d
                      WHERE d.lead_key = m.lead_key
                        AND d.decision IN ('approve', 'reject', 'snooze', 'closed'))
    RETURNING m.lead_key
  )
  SELECT coalesce(array_agg(r.lead_key), '{}') INTO v_keys FROM r;

  INSERT INTO pipeline_events (event, rubric_version, leads_affected, lead_keys, reason, actor)
  VALUES ('reset_scores', p_rubric, cardinality(v_keys), v_keys, p_reason, 'operator');

  RETURN QUERY
    SELECT m.lead_key, m.business_name FROM leads_master m
    WHERE m.lead_key = ANY (v_keys);
END; $$ LANGUAGE plpgsql;
