# SOL Lead Engine · FAQ (General Edition)

*v1.0 · questions from business owners first, then technical ones.*

---

## For business owners

**What does it actually do?**
Every morning it finds local businesses in your area and niche, visits each website the way a customer would, and scores how much a weak online presence is likely costing them. v1 runs on yoga and pilates studios around Austin, Texas, at 8:00 am Austin time. The ones worth a look arrive on your phone as a card, and the rest arrive together as 1 short daily summary.

**Does it contact anyone by itself?**
No. Version 1 never sends a message to a business. It finds, audits and scores, and you decide; that's **human-in-the-loop**, meaning anything with a client's name, money, legal weight, or that can't be undone waits for a person to approve it. Outreach is a later version, and it would still wait for your approval.

**Is it legal?**
It uses OpenStreetMap, a public map whose data may be stored and reused under its open license, and it reads public websites gently (1 page every 2 seconds). It stores **business facts only**, never profiles of people. Any future outreach follows the rules of the target country; in the US that's CAN-SPAM, which asks for an honest sender and subject line, a real postal address and a working opt-out.

**Why should I trust a score?**
Because every point is listed on the card with its reason ("No online booking +10"). The scoring is **deterministic**, meaning fixed rules decide, not an AI's guess, so the same business always gets the same score, and 11 unit tests check the rules before any change goes live.

**What if it gets something wrong?**
You see the evidence before you decide. If the map is missing a website, tap **Add website** and reply with the address: the business is re-audited and rescored. Every decision you make is logged.

**How much does it cost to run?**
The services it uses have free tiers (the database, the map, Telegram). The main cost is where it runs: free on your own computer while it's on, or a small monthly fee for a server or n8n Cloud if you want it on all the time.

**Does it work for my industry?**
It's built and calibrated for **appointment businesses**: studios, salons, clinics, tutors. Other industries need their scoring rules adjusted; see *Customize It*.

---

## Technical

**Why rules instead of AI for scoring?**
Rules are explainable, free to run, and never make things up. AI is useful for reading messy text, but a decision that affects who gets contacted should be one you can explain line by line.

**Why polling every minute instead of a webhook?**
A webhook needs the machine to be reachable from the internet (a tunnel or a server). Polling just asks Telegram "anything new?" and needs neither. The cost is up to a minute's delay on a tap.

**Why is scoring a separate Python service?**
Not every n8n install includes a Python runner. A small service works everywhere, can be tested on its own (11 tests), and keeps the rules in one readable file.

**What stops duplicates?**
**Dedupe**, meaning the same business is never saved twice. Every lead is keyed on its map ID, and every save is an upsert, so re-running the miner updates records instead of adding new ones; that makes it **idempotent**, where running it twice gives the same result as once. Taps are checked against the lead's status, so a second tap on the same card changes nothing.

**What stops someone else pressing my buttons?**
A decision is written only if the tap comes from the chat the card was sent to, the action is on an allowed list, and the lead is still waiting.

**Can the database history be changed?**
The decision log and score history are append-only: the database refuses edits and deletes on those tables. Resets go through a function that requires a reason and logs itself.

**What happens when a service is down?**
Every workflow breaks at some point, so errors are planned for. Steps that only read data use **safe retries**: they try again on their own, 3 times, 5 seconds apart, because trying again there can't hurt anything. Steps that write data don't retry, so nothing is saved twice. The map has a second server to fall back on, and anything that still fails stops and sends an error alert naming the step, the reason and a link to the run, leaving the data in a state the next run can pick up from.

**What time does it run, and why Austin time?**
The daily run fires at 8:00 am in the workflow's timezone, which is set to America/Chicago because the market is Austin. That keeps the schedule and the time stamped on each card in the same local time as the businesses being audited. Pointing it at a new market? Set the workflow's timezone to that market's.

**Why did I get an alert that says "Host not found" or "connection timed out"?**
Usually a short internet drop. If it happens once and the next run succeeds, it was a blip. If it repeats, check your connection, the database status page, and the Runbook.

**What does "needs_check" mean?**
The map listing is missing key details (often the website), so the engine won't guess. You choose: Add website, Confirm no site, or Closed.

**What's the difference between needs_check and check_alive?**
`needs_check`: no website on the map, so the facts are unknown. `check_alive`: there is data, but it looks dead (for example, a site that no longer loads and no phone or hours).

**Why do cold leads not get cards?**
They're doing fine for now. Sending a card for each would bury the leads that matter, so they're listed once in a daily summary and kept in the database.

**Can it run in Docker or on n8n Cloud?**
Yes. The only part that changes is the address the Score node uses to reach the scoring service. See *Set Up From Zero*, Step 0.

**Does it work with a database other than Neon?**
Any PostgreSQL 13 or newer.

---

## Plain English glossary

| Term | Meaning |
|---|---|
| **cron / schedule** | a timetable for computers: "run this at 8:00 am every day" |
| **timezone** | the local clock a workflow reads; SOL uses America/Chicago (Austin), so 8:00 am means 8:00 am in Austin |
| **localhost** | this computer; `localhost:5678` is a program on this machine listening at door 5678 |
| **REST API** | apps talking through web addresses: GET to ask, POST to tell |
| **CRUD** | Create, Read, Update, Delete: the 4 things you do with data |
| **upsert** | "insert, or update if it already exists": the reason re-runs never duplicate |
| **idempotent** | doing it twice gives the same result as once |
| **polling** | asking "anything new?" on a timer |
| **webhook** | the other side calling you when something happens |
| **tunnel** | a secure outbound pipe that lets the internet reach a local program |
| **migration** | a numbered SQL file that changes the database's shape |
| **append-only** | a log you can add to but never edit or delete |
| **deterministic** | fixed rules decide, so the same input always gives the same result |
| **human-in-the-loop** | anything with a client's name, money, legal weight, or that can't be undone waits for a person to approve it |
| **dedupe** | the same record is never saved twice |
| **safe retries** | a step tries again on its own only where trying again can't cause harm, such as reading data |
| **JSON** | the labelled-box format apps use to pass data |
| **environment variable** | a setting stored by the computer, outside the workflow, often for secrets |
| **fixture** | saved test data that behaves like the real thing |
