# SOL Lead Engine · Set Up From Zero (General Edition)

*v1.0 · rubric v0.3 · for anyone setting the engine up, on any machine or host.*

> **Living document.** When a step changes, this file is edited and the docs are rebuilt with `py tools/build_docs.py`. Nothing here contains a real key, token or ID.

> **Not locked in.** The engine needs four things: an n8n instance, any PostgreSQL 13+ database, Python 3.10+, and a Telegram bot. The reference build used Neon, a laptop and pm2; every one of those is swappable, and each step below shows the alternatives.

---

## What you need

| Piece | What it's for | Options | Cost |
|---|---|---|---|
| **n8n** | runs the workflow | self-hosted (npm or Docker), on a VPS, or n8n Cloud | free self-hosted |
| **PostgreSQL 13+** | stores leads, scores, decisions and logs | Neon, Supabase, a managed Postgres, or Postgres in Docker | free tiers exist |
| **Python 3.10+** | runs the scoring rules | any OS; standard library only | free |
| **Telegram** | review cards, decisions, error alerts | an account and a bot | free |
| **OpenStreetMap Overpass API** | finds businesses on the map | public servers, no key | free |

About 60 to 90 minutes the first time.

> **Plain English: what is localhost:5678?** "localhost" means *this computer*. 5678 is the door number n8n listens on, so `http://localhost:5678` is n8n running on your own machine, reachable only from that machine. The scoring service works the same way on door 8765.

---

## Step 0 · Choose where it runs

The workflow calls the scoring service once per lead, so **n8n must be able to reach it**. That's the only part that changes between setups:

| Where n8n runs | Where the scoring service runs | Score node URL |
|---|---|---|
| **Your computer (npm)** | same computer | `http://127.0.0.1:8765/score` (as shipped) |
| **Docker on your computer** | on the host | `http://host.docker.internal:8765/score` |
| **Docker Compose / VPS** | its own container in the same Compose network | `http://scoring:8765/score` (service name), with `RECON_SCORE_HOST=0.0.0.0` inside the container |
| **VPS without Docker** | same VPS | `http://127.0.0.1:8765/score` |
| **n8n Cloud** | a small VPS or container host you control | `https://your-host/score`, **behind HTTPS and with `RECON_SCORE_KEY` set** |

**Keeping the service running** (pick one): pm2 (`pm2 start score_service.py --interpreter python --name sol-score`, then `pm2 save`), a Docker container with `restart: unless-stopped`, a systemd service on Linux, or Windows Task Scheduler "at startup".

> **Plain English: what is a server?** Just a computer that stays on and answers requests. "Self-hosting" means that computer is yours (a laptop or a rented VPS); "cloud" means someone else runs it for you.

---

## Step 1 · The database (any PostgreSQL 13+)

1. Create a database on your chosen host (Neon, Supabase, managed Postgres, or `postgres` in Docker).
2. Open its SQL editor (or `psql`) and run each file in `database/`, **in order**: `01` → `03` → `04` → `05` → `06` → `07` → `08`. Each file says what it adds and ends with a **CHECK** query.
3. Note the host, port, database, user and password for Step 4. For hosted databases, SSL is usually required.

> **Plain English: what is CRUD?** The four things you do with stored data: **C**reate, **R**ead, **U**pdate, **D**elete. The engine almost never deletes: decisions and score history are *append-only* (rows can be added, never edited or removed), so the paper trail can be trusted.

> **Plain English: what is a migration?** A numbered SQL file that changes the database's shape. Running them in order rebuilds the exact same database anywhere.

---

## Step 2 · The Telegram bot

1. In Telegram, open **@BotFather**, send `/newbot`, and pick a name and a username ending in `bot`.
2. BotFather replies with a **token**. **Treat it like a password**: anyone with it controls your bot.
3. Send your bot any message.
4. Find your **chat id**: open `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates` and look for `"chat":{"id": ...}`. Close the tab afterwards (the token is in the address).

**If the token leaks:** BotFather → `/mybots` → your bot → **API Token** → **Revoke current token**, then replace it everywhere. Taps made just before a revoke can be lost; tap again on a fresh card.

> **Plain English: what is a REST API?** Apps talking through web addresses. The workflow *asks* Telegram for news with a GET request (`/getUpdates`) and *tells* it to do things with POST requests (`/editMessageReplyMarkup`).

---

## Step 3 · The scoring service (Python)

1. Install Python 3.10+. Check with `python --version`.
2. From the `scoring` folder, run the tests: `python -m unittest -v test_rubric`. All 11 should say `ok`.
3. Start it: `python score_service.py`, then open `http://127.0.0.1:8765/health`. Expect `{"ok": true, "rubric_version": "v0.3"}`.
4. Keep it running with one of the options in Step 0.

| Setting (environment variable) | Default | When to change it |
|---|---|---|
| `RECON_SCORE_HOST` | `127.0.0.1` | `0.0.0.0` only inside a private Docker network |
| `RECON_SCORE_PORT` | `8765` | if the port is taken |
| `RECON_SCORE_KEY` | empty (off) | **set it whenever anything other than localhost can reach the service**; then add the header `X-Score-Key` to the Score node |

> **Why a separate service and not Python inside n8n?** Not every n8n install ships the Python runner (the npm install doesn't). A small service runs anywhere, can be tested on its own, and keeps the rules in one file.

---

## Step 4 · n8n

1. Import `workflow/sol-lead-engine.json` (⋯ → **Import from File**).
2. **Postgres credential:** Credentials → New → Postgres; paste the connection details, set SSL as your host requires, **Test**. Attach it to every Postgres node (they show ⚠ until you do).
3. **Telegram credential:** Credentials → New → Telegram API → paste the token → Test. Attach it to every Telegram node.
4. **Bot token in three HTTP nodes:** **Get Updates**, **Edit Card** and **Edit Old Card** call Telegram directly. Replace `<YOUR_BOT_TOKEN>` in each URL (keep the field in Expression mode). Cleaner alternative: an environment variable read with `{{ $env.YOUR_VAR }}`, which needs `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`.
5. **Score node:** set the URL for your setup (Step 0). If you set `RECON_SCORE_KEY`, add the header `X-Score-Key`.
6. **Workflow Settings:** your timezone · Error Workflow = this workflow · successful production executions **Do not save** (Poll Taps runs 1,440 times a day) · failed executions **Save**.

> **Plain English: credentials and environment variables.** Secrets belong in n8n's credential store or the server's environment, never typed into a node or a config field. That's what lets this workflow be published without leaking anything.

---

## Step 5 · Config: point it at your market

**Config** sits on the main path, right after **Daily Run**. It's the only node you edit.

| Field | Example | What it does, and how to set it |
|---|---|---|
| `city` | `Austin` | A label used in run logs and batch names. It does **not** decide where the search happens; lat/lon do. |
| `lat`, `lon` | `30.2672`, `-97.7431` | The centre of the search. **Getting them:** in Google Maps, right-click the spot and click the numbers at the top of the menu to copy them; or on openstreetmap.org, right-click → *Show address*. First number is latitude, second is longitude. |
| `radius_m` | `40000` | Search radius in **metres** (40000 = 40 km). Start small (10000 to 20000) in dense cities; huge areas are slow and can time out on the public servers. |
| `niche` | `yoga|pilates` | Keywords matched against the map's sport tag **and** the business name. The `|` means **OR**: `yoga|pilates` finds places matching either word. **You can add as many as you like**: `yoga|pilates|barre|spin`. Matching ignores upper/lower case. Each business is labelled with every keyword it matches, e.g. `yoga_pilates`. Keep keywords to letters and spaces; symbols like `( ) . *` have special meaning. |
| `country` | `US` | Default country when the map doesn't say. Also switches the email rule: `US` allows email (with an opt-out), `GB` blocks it. |
| `batch_size` | `10` | How many websites are audited per run. **Can it be bigger? Yes**, but each site takes about 2 seconds plus its contact page, so 50 means roughly 3 to 4 minutes per run. Bigger batches finish a backlog faster; smaller ones are gentler on websites and easier to watch. 10 to 30 is a good range. |
| `use_fixture` | `true` | `true` = the saved Austin test set (no live calls), `false` = live OpenStreetMap. Keep `true` while setting up. |
| `review_chat_id` | your chat id | Where cards and summaries go. A group chat works too (its id starts with `-`). |

**Two niches at once?** Yes, as long as they belong together (`yoga|pilates`). For **unrelated** niches (`yoga` and `plumber`), run them as separate copies of the workflow, because the scoring rules are tuned per kind of business.

> **The rubric is niche-shaped.** The rules in `scoring/recon_rubric.py` were calibrated for **appointment businesses** (studios, salons, clinics, tutors): "no online booking" is a real frustration there. For a different kind of business, review the rules and add test cases before trusting the scores.

---

## Step 6 · First run (safe mode)

1. Keep `use_fixture` = **true**. Click **Execute** on **Daily Run**.
2. Check: `SELECT automation_status, count(*) FROM leads_master GROUP BY 1;`
3. Cards and a cold summary arrive in Telegram. **Tap a button**, then Execute on **Poll Taps**. The card should change to a label like "Snoozed 14 days".
4. Set `use_fixture` = **false** and **Publish**. It now runs daily at 2:00 pm and reads taps every minute.

> **Plain English: what is cron?** A timetable for computers: "run this at 2 pm every day". n8n's Schedule Trigger is cron with a friendly face.

> **Plain English: polling vs webhooks.** A webhook is Telegram *calling you*; it needs your n8n reachable from the internet (a tunnel or a server). Polling is *you asking* "anything new?" every minute and needs neither, which is why this build uses it.

> **Plain English: what is tunnelling?** A secure pipe your machine opens *outwards* (e.g. Cloudflare Tunnel) so the internet can reach a local service without opening your network. Only needed for webhooks.

---

## Step 7 · Security: what's protected, and what you must do

**Already built in**

| Risk | How the engine handles it |
|---|---|
| **SQL injection** | Every database query uses **parameters** (`$1`, `$2`...). Values are sent separately from the SQL, so text from a website or a Telegram reply can never become a command. |
| **Prompt injection** | There is **no AI model in the pipeline**. Website text is matched with fixed patterns and never given to a model as instructions, so there's nothing to inject into. (Any future AI step must treat website text as data only.) |
| **Strangers pressing your buttons** | A decision is written only if the tap comes from the **chat the card was sent to**, the action is on an allowed list, and the lead is still waiting. |
| **Bad input in replies** | Add website accepts only something shaped like a web address, for a lead still waiting on a decision. |
| **Hostile websites** | Pages are read as plain text (never run), with a 10 second timeout and a size cap on what's scored. |
| **Secrets in the workflow file** | Credentials live in n8n's store; the published workflow has none, and the build's leak check blocks tokens, chat ids and personal paths. |
| **Duplicate or replayed actions** | Upserts and status checks make every step safe to repeat. |
| **Personal data** | Business facts only. No owner profiles, and OpenStreetMap contributor names are never stored or published. |

**Your part**

- **Never expose the n8n editor** to the internet without a login and HTTPS. On a VPS: a firewall, n8n's user management, and a reverse proxy with HTTPS.
- **Keep the scoring service private** (`127.0.0.1` or a private Docker network), or set `RECON_SCORE_KEY` and HTTPS if it must be reachable.
- **Use SSL** to your database, and a database user that only has access to this database.
- **Rotate the bot token** if it's ever seen by anyone (screenshot, shared file).
- **Keep n8n updated**; most security fixes arrive in updates.
- **Back up the database** (most hosts do this; check retention).

---

## Step 8 · Keep it healthy

| Check | How |
|---|---|
| Is the scoring service up? | open `/health` on its address |
| Did today's run happen? | n8n → Executions, or `SELECT * FROM mining_runs ORDER BY id DESC LIMIT 1;` |
| What did I decide? | `SELECT * FROM lead_decisions ORDER BY id DESC;` |
| Why did a score change? | `SELECT * FROM score_history WHERE lead_key = '...' ORDER BY scored_at;` |
| Something broke? | the error lane sends the node, the reason and a link to the run |

**Uptime note.** The engine runs only while n8n and the scoring service are running. On a laptop that means while it's on; on a VPS or with n8n Cloud plus a hosted service, it's 24/7.

> **Plain English: what is idempotent?** Doing something twice gives the same result as once. Re-running the miner never duplicates a lead; tapping twice records one decision.

> **Plain English: what is JSON?** The labelled-box format apps use to pass data: `{"business_name": "Studio Satya", "final_score": 34}`. n8n moves JSON from node to node.
