# SOL Lead Engine

**Finds the local businesses customers struggle to reach online, audits each website the way a customer would experience it, scores what that's costing them, and keeps a human in the loop before anything happens.**

**▶ Explore the live workflow: https://anruops.github.io/sol-lead-engine/**

Built in n8n with PostgreSQL, a tested Python scoring service and a Telegram review gate. v1 is pointed at yoga and pilates studios in a box reaching 40 km (about 25 miles) out from central Austin, Texas, in each direction (the corners reach about 35 miles, out to towns like Wimberley), and it runs every morning on Austin time, unattended; when anything breaks, it tells you within a minute.

## What it does

```
MAIN PATH · every day at 8:00 am Austin time (America/Chicago)
  Config (area · niche · country · batch size · test mode)
    → Mining     OpenStreetMap, with a mirror fallback and a fake-success check
    → Refinery   clean lead records · chains and closed places flagged · no duplicates, ever
    → Audit      homepage + contact page: HTTPS, mobile, booking, contact, email, socials
    → Score      Python rules service: Opportunity (70) + Viability (30), every point explained
    → Cards      hot / warm / holds → Telegram card with buttons · cold → one daily summary

POLL TAPS PATH · every minute
  your tap → decided once, logged forever → the card updates
  "Add website" → reply with the URL → re-audited, copied to the brand's other locations

ERROR LANE
  any failed run → Telegram: which node, what happened, link to the run
```

## Design rules

Each rule names the term, what it means, why it's there and how SOL does it.

- **Deterministic scoring.** Fixed rules decide, not AI, so the same business always gets the same score. *Why:* a score that decides who gets contacted has to be explainable. *How:* a Python rules service scores Opportunity (up to 70) + Viability (up to 30) = a score out of 100, lists the reason for every point, and is guarded by 11 unit tests.
- **An unknown is not a no.** Missing data never earns points. *Why:* a map listing with no website isn't proof the business has no booking or email. *How:* those leads become a `needs_check` card that asks the reviewer to look, instead of a guess.
- **Human-in-the-loop.** Anything with a client's name, money, legal weight, or that can't be undone waits for a person to approve it. *Why:* a wrong automated call there costs trust. *How:* the engine automates the finding, auditing and scoring, so the reviewer's time goes to the lead and how to turn it into a client, with onboarding handed off to LUNA (planned next). Each lead worth a look becomes a Telegram card with its facts and links; the reviewer verifies them, checks how the website feels to book on (kept human on purpose), and decides with 1 tap.
- **Dedupe and idempotent re-runs.** Dedupe means the same business is never saved twice; idempotent means running it twice gives the same result as running it once. *Why:* the miner runs every day over the same area. *How:* every lead is upserted on its map ID, and a duplicate or stale tap is refused.
- **Append-only log.** A record that can be added to but never edited or deleted. *Why:* there's always a true history of what was decided and what the score was at that moment. *How:* `lead_decisions`, `score_history` and `pipeline_events` refuse edits and deletes at the database level.
- **Compliance first.** Business facts only, never profiles of people. *Why:* public business data is fair to audit; people aren't. *How:* the engine stores no personal data, and any future outreach follows the target country's rules (in the US, CAN-SPAM: an honest sender and subject line, a real postal address and a working opt-out).
- **Errors are planned for.** Every workflow breaks at some point. *Why:* a workflow that fails quietly costs days. *How:* steps that only read data use safe retries (3 tries, 5 seconds apart), steps that write data don't retry so nothing is saved twice, and the error lane sends the failed node, the reason and a link to the run.

## Repository

| Path | What it is |
|---|---|
| `index.html` | the showcase page with the interactive canvas (GitHub Pages) |
| `workflow/sol-lead-engine.json` | the n8n workflow, credentials and personal values removed |
| `database/` | Postgres migrations 01 and 03 to 08, run in order |
| `scoring/` | the Python rubric, the local scoring service, and 11 tests |
| `docs/System-Guide.md` | every node: where it sits, why it exists, its settings and code |
| `docs/Set-Up-From-Zero.md` | accounts, credentials, database, scoring service, first run (any setup) |
| `docs/Customize-It.md` | new area, new niche, new kind of business, changing the scoring rules |
| `docs/FAQ.md` | questions from business owners and builders, plus a plain-English glossary |
| `docs/Runbook.md` | what to do when something looks wrong (every entry is a real incident) |
| `docs/Case-Study.md` | the problem, the build, the decisions, and measured test results |
| `docs/Reference.md` | architecture diagram, data dictionary, calibration log |
| `CHANGELOG.md` | what changed and when |

## Quick start

1. Create any PostgreSQL 13+ database (Neon, Supabase, managed, or Docker) and run the migrations in `database/` in order.
2. Start the scoring service: `python scoring/score_service.py` (Python 3.10+, no installs), then open `http://127.0.0.1:8765/health`. Running n8n in Docker or n8n Cloud? See Step 0 of the setup guide for the right address.
3. Import `workflow/sol-lead-engine.json` into n8n, attach your Postgres and Telegram credentials, and put your bot token where it says `YOUR_TELEGRAM_BOT_TOKEN`.
4. Edit **Config**: your area, niche keywords, country and chat id. Leave `use_fixture` on for the first run.
5. In **Workflow Settings**, set the timezone to your market's (the shipped workflow uses America/Chicago for Austin), so the daily run and the card timestamps read in the market's local time.
6. Run it, tap a card, then switch `use_fixture` off and publish.

Step-by-step, with every credential explained: `docs/Set-Up-From-Zero.md`.

## Stack

n8n (npm, Docker or Cloud) · PostgreSQL (built on Neon, runs on any Postgres 13+) · Python (standard library) · OpenStreetMap Overpass API · Telegram Bot API · JavaScript (n8n Code nodes) · SQL

## How I work with AI

Claude was my guide and reviewer. Every change was proven in a controlled run first (test data, one change at a time, checked against the database and the logs) before it touched the live system, and the scoring rules are guarded by tests so a change that breaks a known case fails loudly.

*Built by Angela Rubia, Systems-first AI & Automation Engineer.*
