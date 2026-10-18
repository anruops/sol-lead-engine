-- =====================================================================
-- RECON v1 · 07 · Cold summary
-- Run AFTER 06_manual_website.sql, in the Neon SQL Editor.
--
-- Cold leads get no card each. They are listed once in a daily summary,
-- and summarized_at makes sure no lead is listed twice.
-- =====================================================================
ALTER TABLE leads_master ADD COLUMN IF NOT EXISTS summarized_at TIMESTAMPTZ;

-- ===== CHECK =====
-- SELECT count(*) FILTER (WHERE summarized_at IS NOT NULL) AS summarized FROM leads_master;
