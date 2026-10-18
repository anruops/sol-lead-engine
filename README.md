# SOL Lead Engine

**Finds the local businesses customers can't reach online, audits each website like a frustrated customer, scores what that is costing them, and puts every lead in front of a human before anything happens.**

**▶ Explore the live workflow: https://anruops.github.io/sol-lead-engine/**

Built in n8n with PostgreSQL, a tested Python scoring service and a Telegram review gate. It runs every day, unattended, and tells you within a minute when anything breaks.

## What it does

```
MAIN PATH · every day at 2:00 pm
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

- **Rules decide, not AI.** Scoring is deterministic, explainable point by point, and covered by tests.
- **An unknown is not a no.** Missing data becomes a "check this" card, never a guess.
- **A human approves every lead.** Nothing moves without a tap, and every tap is logged in an append-only table.
- **Safe to re-run.** Upserts on stable keys; duplicate or stale taps are refused.
- **Compliance first.** Business facts only, no personal profiling; UK sole traders are never emailed.
- **It tells you when it breaks.** Retries for blips, an error lane for real failures.

## Repository

| Path | What it is |
|---|---|
| `index.html` | the showcase page with the interactive canvas (GitHub Pages) |
| `workflow/sol-lead-engine.json` | the n8n workflow, credentials and personal values removed |
| `database/` | Postgres migrations 01 and 03 to 08, run in order |
| `scoring/` | the Python rubric, the local scoring service, and 11 tests |
| `docs/System-Guide.md` | every node: where it sits, why it exists, its settings and code |
| `docs/Set-Up-From-Zero.md` | accounts, credentials, database, scoring service, first run |
| `CHANGELOG.md` | what changed and when |

## Quick start

1. Create any PostgreSQL 13+ database (Neon, Supabase, managed, or Docker) and run the migrations in `database/` in order.
2. Start the scoring service: `python scoring/score_service.py` (Python 3.10+, no installs), then open `http://127.0.0.1:8765/health`. Running n8n in Docker or n8n Cloud? See Step 0 of the setup guide for the right address.
3. Import `workflow/sol-lead-engine.json` into n8n, attach your Postgres and Telegram credentials, and put your bot token where it says `<YOUR_BOT_TOKEN>`.
4. Edit **Config**: your area, niche keywords, country and chat id. Leave `use_fixture` on for the first run.
5. Run it, tap a card, then switch `use_fixture` off and publish.

Step-by-step, with every credential explained: `docs/Set-Up-From-Zero.md`.

## Stack

n8n (npm, Docker or Cloud) · PostgreSQL (built on Neon, runs on any Postgres 13+) · Python (standard library) · OpenStreetMap Overpass API · Telegram Bot API · JavaScript (n8n Code nodes) · SQL

## How I work with AI

Claude was my guide and reviewer. Every change was proven in a controlled run first (test data, one change at a time, checked against the database and the logs) before it touched the live system, and the scoring rules are guarded by tests so a change that breaks a known case fails loudly.

*Built by Angela Rubia, Systems & AI Automation Engineer.*
