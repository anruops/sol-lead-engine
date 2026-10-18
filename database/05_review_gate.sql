-- =====================================================================
-- RECON v1 · 05 · Review gate (Lane 5)
-- Run AFTER 04_score_history_events.sql, in the Neon SQL Editor.
--
--   * leads_master gets the card columns: when the card went out, and the
--     Telegram message id so the card can be edited once you decide
--   * telegram_poll_state keeps the polling offset, so a button tap is
--     read exactly once (no webhook, no tunnel)
-- Additive only: nothing existing is dropped or renamed.
-- =====================================================================
BEGIN;

-- 1) Card columns.
ALTER TABLE leads_master
  ADD COLUMN IF NOT EXISTS review_sent_at     TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS review_chat_id     BIGINT,
  ADD COLUMN IF NOT EXISTS review_message_id  BIGINT;

CREATE INDEX IF NOT EXISTS idx_leads_review_queue
  ON leads_master (automation_status, review_sent_at);

-- 2) Polling offset: Telegram's getUpdates returns every update after
--    last_update_id. One row per bot.
CREATE TABLE IF NOT EXISTS telegram_poll_state (
  bot             TEXT        PRIMARY KEY,
  last_update_id  BIGINT      NOT NULL DEFAULT 0,
  polled_at       TIMESTAMPTZ
);

INSERT INTO telegram_poll_state (bot) VALUES ('recon')
ON CONFLICT (bot) DO NOTHING;

COMMIT;

-- ===== CHECK (run after) =====
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'leads_master' AND column_name LIKE 'review_%';
--   expect 3 rows
-- SELECT * FROM telegram_poll_state;
--   expect 1 row: recon | 0
