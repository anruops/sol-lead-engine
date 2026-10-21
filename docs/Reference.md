# SOL Lead Engine · Reference: architecture, data and calibration (General Edition)

*v1.0 · rubric v0.3 · the things to look up while working on the engine.*

---

## 0 · Terms used in this repo

*Scripts, posts and applications use these exact words. Each term reads left to right: what it means in plain words, why SOL uses it, and how it's built here.*

| Term | Plain meaning | Why | How in SOL |
|---|---|---|---|
| **lanes** | the stages of the main path, each with its own sticky note | a reader can follow 1 job at a time | 5 lanes: mining, refinery, audit, score, review gate (plus the cold summary); decisions run on the Poll Taps path; failures go to the error lane |
| **deterministic scoring** | fixed rules decide, so the same input always gives the same score | a score that decides who gets contacted must be explainable | Opportunity (up to 70) + Viability (up to 30) = a score out of 100, every point listed with its reason, guarded by 11 unit tests |
| **an unknown is not a no** | missing data never counts against a business | a map with no website listed isn't proof there's no booking or email | the lead becomes a `needs_check` card asking the reviewer to look |
| **human-in-the-loop** | anything with a client's name, money, legal weight, or that can't be undone waits for a person to approve it | a wrong automated call there costs trust or money | the engine gathers the facts on a Telegram card; the reviewer verifies them, judges how the website feels to book on (never handed to code), and decides with 1 tap |
| **review gate** | the step where the reviewer checks the facts and decides | the engine automates the manual work, so the reviewer's time goes to the lead and how to turn it into a client | Telegram cards with Approve / Reject / Snooze 14 days, or Add website / Confirm no site / Closed, plus Website, Map entry and Search links for manual research |
| **dedupe** | the same business is never saved twice | the miner covers the same area every day | every lead is keyed on its OpenStreetMap ID |
| **idempotent** | running it twice gives the same result as running it once | re-runs and double taps happen | leads are upserted on the map ID; a second tap on a decided card changes nothing |
| **status machine** | every lead is always in exactly 1 named state | you can always tell where a lead is and what comes next | new → audited → scored → in_review → approved, rejected or snoozed (or excluded) |
| **append-only log** | a record that can be added to but never edited or deleted | there's always a true history of what was decided and what the score was then | `lead_decisions`, `score_history` and `pipeline_events`; the database refuses edits and deletes |
| **safe retries** | a step tries again on its own only where trying again can't cause harm | most failures are short blips | steps that only read (map, Telegram polling, batch reads) retry 3 times, 5 seconds apart; logging steps don't retry, so nothing is written twice |
| **error lane / error handler** | the part of the workflow that runs when another part fails | every workflow breaks at some point, so errors are planned for | any failed published run sends the node, the reason and a link to that run to Telegram within a minute |
| **calibration** | adjusting the rules against real leads, version by version | the first rules were wrong in ways only real data showed | rubric versions v0.1 → v0.3, each applied with a logged reset that keeps every old score |
| **timezone** | the local clock the workflow reads | the schedule and card timestamps should match the market being audited | Workflow Settings → America/Chicago (Austin); the daily run fires at 8:00 am Austin time |

---

## 1 · Architecture

```
                         ┌──────────────────────── MAIN PATH · daily 8:00 am Austin ─────────────────┐
 Daily Run → Config → Search Area → Live or Fixture?
                                    ├─ fixture → OSM Fixture ─┐
                                    └─ live ───→ OSM Fetch ───┼→ OSM OK? ─ no → Mining Failed (alert)
                                                 └ error → OSM Fetch (Mirror) ┘   │ yes
                                                                                  ▼
   One per Place → Normalize → Upsert Leads → Log Mining Run                     [Refinery]
        → Next Batch → Anything to Audit? ─ yes → Visit Website → Audit Signals
                                │                 → Visit Contact Page → Merge Contact → Save Audit
                                └ no ─────────────────────────────────────────────┐   │
        → Score Batch ←────────────────────────────────────────────────────────────┴───┘
        → Anything to Score? ─ yes → Score (Python service) → Save Score → Log Score Run
                                │                                              │
                                └ no ──────────────┬───────────────────────────┘
                                                   ├→ Review Batch → Build Card → Needs Check?
                                                   │      → Send Needs-Check Card / Send Review Card → Mark Sent
                                                   └→ Cold Batch → Build Summary → Send Summary → Mark Summarized

                         ┌──────────────────── POLL TAPS PATH · every minute ────────────────────┐
 Poll Taps → Get Offset → Get Updates → Any Updates? → Save Offset → One per Update → Parse Tap → Route
   Route ─ tap → Is Add Website? ─ yes → Ask for URL → Answer Add Website
                               └ no → Write Decision → Decided? ─ yes → Edit Card → Answer Tap
                                                              └ no → Answer Stale
   Route ─ website_reply → Save Website → Website Saved? ─ yes → Edit Old Card → Confirm Website
                                                       └ no → Reply Invalid

                         ┌──────────────────── ERROR LANE · any failed published run ────────────┐
 Error Trigger → Error Alert
```

**Outside services:** OpenStreetMap Overpass (main + mirror) · business websites (read only) · the scoring service (local HTTP) · Telegram Bot API · PostgreSQL.

---

## 2 · Data dictionary

### Lead lifecycle (`automation_status`)

```
new → audited → scored → in_review → approved | rejected | snoozed (returns after 14 days)
 └→ excluded (chain, closed, off-niche, no name; or marked closed by you)
```
`confirm_no_site` sends a lead back to `audited` for a normal score; `Add website` sends it back to `new` for a fresh audit.

### Tables

| Table | One row per | Key columns | Notes |
|---|---|---|---|
| `leads_master` | business | `lead_key` (map ID, unique), `business_name`, `target_niche`, `address`, `city`, `country`, `lat`, `lon`, `phone`, `website_url`, `website_source`, `automation_status` | the main record. Some columns from the original design (e.g. `linkedin_url`, `quality_score`) are unused in v1 and kept for later versions |
| *(audit columns on `leads_master`)* | | `site_status` (none/ok/down/blocked), `https`, `mobile_ready`, `copyright_year`, `has_booking`, `booking_provider`, `has_contact_form`, `emails_found`, `audit_details` (JSON), `audited_at` | written by Save Audit |
| *(score columns on `leads_master`)* | | `opportunity_pts`, `viability_pts`, `final_score`, `tier`, `tags`, `score_reasons` (JSON), `rubric_version`, `contact_route`, `email_allowed`, `scored_at` | written by Save Score |
| *(card columns on `leads_master`)* | | `review_sent_at`, `review_chat_id`, `review_message_id`, `snooze_until`, `summarized_at` | written by Mark Sent, Write Decision, Mark Summarized |
| `lead_decisions` | decision | `lead_key`, `decision`, `final_score`, `tier`, `score_reasons`, `rubric_version`, `note`, `decided_via`, `decided_by`, `decided_at` | **append-only**: a snapshot of the score at the moment of deciding |
| `score_history` | score ever given | `lead_key`, `rubric_version`, points, `tier`, `tags`, `score_reasons`, `scored_at` | **append-only**, filled by a trigger on every save |
| `pipeline_events` | run or reset | `event`, `rubric_version`, `leads_affected`, `lead_keys`, `reason`, `actor`, `created_at` | **append-only**: score runs, resets and their reasons |
| `mining_runs` | mining run | `source_batch`, `city`, `niche`, `endpoint` (main/mirror/fixture), `found`, `new_leads`, `excluded` | what was searched and which server answered |
| `telegram_poll_state` | bot | `bot`, `last_update_id`, `polled_at` | the polling offset, so each tap is read once |
| `suppression_list`, `email_log`, `reply_labels`, `review_queue` | | | from the original design; reserved for outreach in a later version |

### Functions

| Function | Does |
|---|---|
| `reset_scores(reason, rubric)` | sends scored leads back for rescoring, skipping any lead with a final decision; refuses to run without a reason; logs itself |
| trigger `record_score_history` | copies every new score into `score_history` |
| triggers `block_*_changes` | refuse UPDATE and DELETE on the append-only tables |

---

## 3 · Calibration log

| Version | Date | Change | Trigger |
|---|---|---|---|
| v0.1 | 2026-10-13 | first points table: Opportunity (70) + Viability (30) | approved anatomy |
| v0.2 | 2026-10-14 | viability counts a working website (6); hours, map edit and social reweighted to 4 | 8 of 10 test leads came out "possibly closed" despite live sites |
| v0.2 | 2026-10-14 | new hold tier `needs_check` split from `check_alive` | every lead on hold was a map listing with missing data, not a closed business |
| v0.2.1 | 2026-10-15 | a lead you confirmed has no website skips the hold | confirmed leads looped back into `needs_check` |
| v0.3 | 2026-10-17 | an unknown is not a no (no listed website = booking/form/email/social not scored); No HTTPS 5 → 8; audit reads the contact page; scoring moved to Python with tests | inflated scores on leads with no listed website; an email missed because it was only on the contact page |

**Every change was applied with a logged reset**, and every earlier score is kept in `score_history`, so any lead's score can be traced through each version.
