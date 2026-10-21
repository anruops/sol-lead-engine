# SOL Lead Engine · Customize It (General Edition)

*v1.0 · rubric v0.3 · how to point the engine at a new market, a new niche, or a different kind of business.*

> **Living document.** Written at the close of v1; updated at the end of each milestone.

---

## What you can change, and how hard it is

| Change | Where | Effort | Needs a rubric check? |
|---|---|---|---|
| A new city or area | Config: `city`, `lat`, `lon`, `radius_m` | 2 minutes | no |
| A related niche (e.g. add barre to yoga and pilates) | Config: `niche` | 2 minutes | no |
| A different appointment business (salon, clinic, tutor) | Config `niche` + OSM Fetch tags + rubric review | 1 to 3 hours | **yes** |
| A very different business (trades, B2B firms) | the above + new rubric rules + tests | a day or more | **yes, a rewrite** |
| How many sites are audited per run | Config: `batch_size` | 1 minute | no |
| When it runs | Daily Run schedule + Workflow Settings timezone | 1 minute | no |
| Where cards go | Config: `review_chat_id` | 1 minute | no |
| The points behind a score | `scoring/recon_rubric.py` + tests | 30 to 60 minutes | it *is* the rubric |

---

## 1 · A new area

1. Open **Config** (main path, right after Daily Run).
2. Set `lat` and `lon` to the center (Google Maps: right-click → click the numbers). Set `city` as a label. v1 ships with central Austin: `30.2672`, `-97.7431`.
3. Set `radius_m`, in meters. Dense cities: 10000 to 20000 (about 6 to 12 miles). Spread-out suburbs: up to 40000 (about 25 miles), which is what v1 uses for Austin. The search is a box, not a circle: `radius_m` is the distance to each edge, so the corners reach about 1.4 times further (40000 reaches about 35 miles at the corners). Very large areas are slow and can time out on the public map servers.
4. Set `country`. `US` marks leads as email-allowed for later outreach; `GB` blocks email by default, because UK rules treat sole traders as individuals.
5. Set the **timezone** in Workflow Settings to the new market's (America/Chicago for Austin), so the daily run and card timestamps read in that market's local time.
6. Run once with `use_fixture` = **false** and check **Log Mining Run**: `endpoint` should be `main` and `found` should be above 0.

> Leads from different areas live side by side in the same database. Each one remembers its own batch name (`source_batch`, e.g. `Austin-2026-10-20`).

## 2 · A related niche

`niche` is a list of keywords separated by `|`, meaning **or**. v1 uses `yoga|pilates`; adding barre would be `yoga|pilates|barre`. Each keyword is matched against the map's sport tag **and** the business name, ignoring capitals. A studio matching 2 keywords is labeled with both (`yoga_barre`).

**Keep related niches together.** They share the same customer frustrations, so the same rubric scores them fairly.

## 3 · A different appointment business

Salons, clinics, tutors and studios work the same way: customers book time, come back, and judge the business by how easy that is online. To switch:

1. **Find the map tags.** On openstreetmap.org, click a few real businesses of that type and note their tags (e.g. `shop=hairdresser`, `amenity=dentist`, `office=tutoring`).
2. **Edit the OSM Fetch query** (main path, Lane 1) in both **OSM Fetch** and **OSM Fetch (Mirror)**. Replace the 2 lines inside the brackets with the new tags, for example:
   ```
   nwr["shop"="hairdresser"];
   nwr["shop"="beauty"]["name"~"{{ $json.niche }}",i];
   ```
3. **Update Config** `niche` with words that appear in those business names (`salon|hair|beauty`).
4. **Check the booking providers** in **Audit Signals** (Lane 3). The list covers fitness tools (Mindbody, Momence, Glofox and others) plus general ones (Calendly, Acuity, Square, Setmore, SimplyBook). Add the tools your niche uses (salons often use Fresha, Booksy or Vagaro).
5. **Run it live**, then read 10 to 20 cards and the cold summary. If good businesses keep landing in the wrong tier, adjust the rubric (section 5).

## 4 · A very different business

For trades (plumbers, electricians) or B2B firms, the frustrations change: "no online booking" is normal for a plumber, and response time or reviews may matter more. That means:

- new or re-weighted rules in `recon_rubric.py`,
- new test cases in `test_rubric.py` that describe a good and a bad lead in that niche,
- usually a separate copy of the workflow, so each niche keeps its own rules and its own Telegram chat.

> **What the engine will not do, by design:** look up people. It stores business facts only, because finding individual owners or employees brings in privacy and consent rules that business facts don't. That stays out of scope.

## 5 · Change the scoring rules

The rules live in one file: `scoring/recon_rubric.py`. Every point has a label, so cards explain themselves.

**Safe way to change a rule:**
1. Edit the rule (for example change `No HTTPS` from 8 to 6 points).
2. Bump `RUBRIC_VERSION` (e.g. `v0.3` → `v0.4`).
3. Add or adjust a test in `test_rubric.py` that shows the intended result.
4. Run `python -m unittest -v test_rubric`. Everything must pass.
5. Restart the scoring service (`pm2 restart <name>` or restart its container).
6. Rescore with a logged reset, so the history records why:
   ```sql
   SELECT * FROM reset_scores('v0.4: No HTTPS 8 to 6 for clinics', 'v0.4');
   ```
7. Run the main path and compare old and new scores in `score_history`.

**Rules of thumb that held up in calibration**
- **An unknown is not a no.** Never give points for something you couldn't check.
- **Score the frustration, not the reach.** A hard-to-reach business is still a lead; reach only decides the contact route.
- **Your judgment beats the rubric on design quality.** How a site looks and feels to book on stays with the reviewer in the review gate, on purpose, so write it in the decision note instead of inventing a rule for it.
- **Research stays manual.** Finding a missing website or working out why a site looks off (a rebrand, a move, a closure) is the reviewer's job through the card's Search link. A rule can only see that something looks off; a person finds out why.

## 6 · Batch size and schedule

- `batch_size` = websites audited per run. Each takes about 2 seconds plus its contact page: 10 ≈ 1 minute, 50 ≈ 3 to 4 minutes. Bigger clears a backlog faster; smaller is gentler on websites.
- **Daily Run** fires at 8:00 am in the workflow's timezone (America/Chicago, so 8:00 am Austin time). Change the hour on Daily Run and the timezone in Workflow Settings; keep 1 run a day unless you have a reason, because the map data rarely changes faster.

## 7 · Before you trust a new setup

Run the pressure test on your change:
- **Live run, not fixture,** for anything that touches the map, a website or Telegram.
- Check counts in the database (`SELECT automation_status, count(*) FROM leads_master GROUP BY 1;`).
- Read real cards. If a score surprises you, look at `score_reasons` for that lead before changing a rule.
