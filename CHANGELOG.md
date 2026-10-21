# Changelog

## 2026-10-22 · v1.0.3 · search area described as a box
- The search area is a box, not a circle: each edge is `radius_m` from the center, so the corners reach about 1.4 times further (40 km edges, about 35 miles at the corners). README, Case Study, Customize It, Set Up From Zero and the System Guide now say so.

## 2026-10-21 · v1.0.2 · v1 documentation complete, Austin time
- New docs: Customize It, FAQ (with a plain-English glossary), Runbook (13 real incidents and their fixes), Case Study (measured test results only), Reference (architecture diagram, data dictionary, calibration log v0.1 to v0.3).
- The workflow now runs on the market's clock: timezone America/Chicago, daily run at 8:00 am Austin time, and card timestamps in Austin time.
- Every term in the README and docs now reads as the term, what it means, why it's there and how SOL does it (Reference section 0 is the full table).
- Compliance notes now follow the US market (CAN-SPAM) instead of UK examples; distances also given in miles.
- The v2 list is now a slow-site signal and proposal drafting. Finding missing websites and checking rebrands stay manual on purpose, in the review gate.

## 2026-10-20 · v1.0.1
- Fixed: the OSM Fetch niche query (line 2 was malformed, so live runs fell back to the mirror). Main and mirror now both read the niche keywords from Config.
- Retry on fail added to Score Batch and Cold Batch (3 tries, 5 s apart).
- Removed a stray line break from the Edit Card and Edit Old Card URLs.
- Workflow JSON now uses plain placeholders (YOUR_TELEGRAM_BOT_TOKEN, YOUR_TELEGRAM_CHAT_ID, YOUR_POSTGRES_CREDENTIAL, YOUR_TELEGRAM_CREDENTIAL) and anonymized test data (SAMPLE_PHONE_n, SAMPLE_EMAIL_n, SAMPLE_WEBSITE_n).
- Set Up From Zero: platform-neutral setup (npm, Docker, VPS, n8n Cloud; any PostgreSQL 13+), full Config guide, and a Security step.
- Scoring service: optional host, port and access key settings.

## 2026-10-18 · v1.0
- First public release: main path (mining, refinery, audit, Python scoring, cards, cold summary), Poll Taps decision path, error lane; System Guide and Set Up From Zero; showcase page.
