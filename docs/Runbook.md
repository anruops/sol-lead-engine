# SOL Lead Engine · Runbook (General Edition)

*v1.0 · what to do when something looks wrong. Every entry is a real problem met while building v1.*

> **First rule:** look before you fix. Open n8n → **Executions**, find the run, and read which node failed and why. One failure followed by successes is usually a blip.

---

## Quick checks

| Question | Check |
|---|---|
| Is the scoring service up? | open its `/health` address; expect `"ok": true` |
| Did today's run happen? | Executions, or `SELECT * FROM mining_runs ORDER BY id DESC LIMIT 1;` |
| Where are the leads? | `SELECT automation_status, count(*) FROM leads_master GROUP BY 1;` |
| What did I decide? | `SELECT * FROM lead_decisions ORDER BY id DESC LIMIT 20;` |
| What was reset, and why? | `SELECT * FROM pipeline_events ORDER BY id DESC LIMIT 20;` |

---

## Breakage catalog

### RUN-1 · "Mining Failed" with http 504, or every run uses the mirror
**Cause:** the main map server rejected the query (often a broken query line) or is overloaded, and the mirror timed out on a big area.
**Fix:** check **OSM Fetch**'s query line by line; the niche line must read `nwr["leisure"="fitness_centre"]["name"~"{{ $json.niche }}",i];` (or your niche's tags). Shrink `radius_m` if the area is huge. Then a **live** run; **Log Mining Run** should say `endpoint: main`.
**Prevent:** after any change to a fetch node, run live, not on the fixture.

### RUN-2 · "Host not found" or "connection timed out" on Get Offset / Get Updates
**Cause:** a short internet drop. Poll Taps runs every minute, so it notices first.
**Fix:** nothing, if the next runs succeed. These steps only read data, so they use safe retries (3 tries, 5 seconds apart), which absorb drops of about 15 seconds; a longer drop still sends an alert, which is the point. If it repeats, check the connection and the database host's status page.

### RUN-3 · A button keeps spinning
**Cause:** the tap hasn't been read yet (polling runs once a minute), or the answer arrived after Telegram's short time limit.
**Fix:** wait a minute. If the card's buttons became a label, the decision was saved; the spinner timing out is harmless (the answer nodes continue on error).

### RUN-4 · I tapped a button and nothing happened, ever
**Cause:** the poll path isn't running (workflow not published), the bot token changed, or taps were made just before a token was revoked (those are lost).
**Fix:** confirm the workflow is published; run **Poll Taps** by hand and look at Get Updates; tap again on a fresh card.

### RUN-5 · Old messages are replayed every minute ("That didn't save" over and over)
**Cause:** **Save Offset** is disabled, so every poll re-reads every update since the stored offset.
**Fix:** enable Save Offset and run Poll Taps once. Only disable it while retesting taps, never while testing replies.

### RUN-6 · Taps vanished after I rewound the offset in the database
**Cause:** Telegram deletes updates for good once a poll asks for a later offset. Rewinding the number doesn't bring them back.
**Fix:** tap again.

### RUN-7 · A website I added came back empty after the next run
**Cause:** re-mining copied the map's (empty) website over yours. Fixed in v1 by migration 06.
**Fix:** check `website_source = 'manual'` on that lead. Hand-added websites are protected from then on.

### RUN-8 · A lead I corrected wasn't rescored after a reset
**Cause:** older resets skipped any lead with any decision. Since migration 08 only final decisions (approve, reject, snooze, closed) protect a lead.
**Fix:** run `reset_scores()` again with a reason.

### RUN-9 · Scores look wrong across the board
**Cause:** usually a rule, not the data. A rule firing on almost every lead is the warning sign.
**Fix:** read `score_reasons` for a few leads; fix the rule in `recon_rubric.py` with a test; bump the version; logged reset. See *Customize It*, section 5.

### RUN-10 · The Score node fails with "connection refused"
**Cause:** the scoring service isn't running, or n8n can't reach its address (Docker and n8n Cloud need a different address).
**Fix:** start it and check `/health`; check the Score node's URL for your setup (*Set Up From Zero*, Step 0). If `RECON_SCORE_KEY` is set, the Score node must send the `X-Score-Key` header.

### RUN-11 · 2 cold summaries in 1 run
**Cause:** the scoring lane ran twice. Fixed in v1: the audit is 1 straight path, so scoring runs once.
**Fix:** if it returns, check that nothing feeds Score Batch from 2 places at once.

### RUN-12 · The bot token leaked
**Fix:** BotFather → `/mybots` → your bot → API Token → **Revoke**. Put the new token in the Telegram credential and in the 3 HTTP nodes (Get Updates, Edit Card, Edit Old Card). Then tap a fresh card to confirm.

### RUN-13 · Card times or the daily run are hours off
**Cause:** the workflow's timezone isn't the market's. The run hour reads the timezone in Workflow Settings, and the time stamped on each card reads the zone set inside Edit Card and Edit Old Card.**Fix:** set Workflow Settings → Timezone to America/Chicago (Austin) or your market's, and set the same zone in the `setZone(...)` of Edit Card and Edit Old Card.

---

## Safe resets (always logged)

| Goal | SQL |
|---|---|
| Rescore everything after a rule change | `SELECT * FROM reset_scores('reason', 'vX.Y');` |
| Resend cards that were deleted from the chat | update the leads back to `scored` with `review_sent_at = NULL`, and insert a `reset_review` row in `pipeline_events` with the reason |
| Re-audit working websites | set them back to `new`, and log a `reset_audit` event |

Never edit `lead_decisions` or `score_history`: the database refuses, by design.
