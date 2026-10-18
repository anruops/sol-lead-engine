-- =====================================================================
-- RECON v1 · 06 · Protect websites added by hand
-- Run AFTER 05_review_gate.sql, in the Neon SQL Editor.
--
-- Why: every main run re-mines OpenStreetMap, and Upsert Leads copied
-- OSM's website over ours. A site added by hand (Add website button or a
-- manual correction) was wiped back to NULL on the next run.
--   * website_source = 'osm' (default) or 'manual'
--   * Upsert Leads keeps the website when website_source = 'manual'
-- =====================================================================
ALTER TABLE leads_master
  ADD COLUMN IF NOT EXISTS website_source TEXT NOT NULL DEFAULT 'osm';  -- osm | manual

-- ===== CHECK =====
-- SELECT website_source, count(*) FROM leads_master GROUP BY 1;
--   expect: osm | <all leads>
