# Changelog

## 2026-10-20 · v1.0.1
- Fixed: the OSM Fetch niche query (line 2 was malformed, so live runs fell back to the mirror). Main and mirror now both read the niche keywords from Config.
- Retry on fail added to Score Batch and Cold Batch (3 tries, 5 s apart).
- Removed a stray line break from the Edit Card and Edit Old Card URLs.
- Workflow JSON now uses plain placeholders (YOUR_TELEGRAM_BOT_TOKEN, YOUR_TELEGRAM_CHAT_ID, YOUR_POSTGRES_CREDENTIAL, YOUR_TELEGRAM_CREDENTIAL) and anonymized test data (SAMPLE_PHONE_n, SAMPLE_EMAIL_n, SAMPLE_WEBSITE_n).
- Set Up From Zero: platform-neutral setup (npm, Docker, VPS, n8n Cloud; any PostgreSQL 13+), full Config guide, and a Security step.
- Scoring service: optional host, port and access key settings.

## 2026-10-18 · v1.0
- First public release: main path (mining, refinery, audit, Python scoring, cards, cold summary), Poll Taps decision path, error lane; System Guide and Set Up From Zero; showcase page.
