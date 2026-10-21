# SOL Lead Engine · Case Study (General Edition)

*v1.0 · built 13 to 20 October 2026 by Angela Rubia, Systems-first AI & Automation Engineer.*

---

## The problem

Many established local businesses (yoga and pilates studios, salons, clinics, tutors) have good reputations and weak digital front doors: no online booking, a contact form that doesn't exist, a site that's slow, old or gone. Their customers feel the friction; the owners often don't see it.

Finding those businesses by hand is slow. Someone has to search the map, open each website, check booking, contact details, security and mobile layout, compare it with nearby competitors and write it up. It's careful, repetitive work, and it's easy to skip steps.

## The goal for v1

1 system that **finds** these businesses, **audits** each website the way a customer would experience it, **scores** what that's likely costing them with deterministic rules, and keeps a **human in the loop** before anything happens, with every decision logged. No outreach in v1, because discovery and judgment come first. The first market is yoga and pilates studios within 40 km (about 25 miles) of central Austin, Texas.

## What I built

A single n8n canvas with 3 paths and 58 working nodes:

- **Main path (daily at 8:00 am Austin time):** OpenStreetMap discovery with a mirror fallback → a refinery that cleans records, flags chains and closed places, and dedupes them so the same business is never saved twice → a website audit of the homepage and contact page → a **Python scoring service** (deterministic rules, 11 tests) → a Telegram card for each lead worth a look, and 1 daily summary for the rest.
- **Poll Taps path (every minute):** reads my button taps, writes each decision once to an append-only log (a record that can be added to but never edited), updates the card, and handles a 2-step "Add website" conversation that copies a corrected website to the same brand's other locations.
- **Error lane:** any failed run sends me the failed step, the reason and a link to that run.

Data lives in PostgreSQL (Neon) across 7 migrations, with append-only decision and score history tables and a reset function that refuses to run without a reason.

## Design decisions that mattered

| Decision | Why |
|---|---|
| **Deterministic scoring** (fixed rules, not AI) | the same business always gets the same score, every point is explained, it's free to run, and it never invents facts |
| **Human-in-the-loop** (a person approves anything with a client's name, money, legal weight, or that can't be undone) | the engine automates the finding, auditing and scoring, so my time goes to the lead and how to turn it into a client; how a website feels to book on is checked by me, on purpose |
| **An unknown is not a no** | missing map data never earns points; it becomes a "check this" card instead of a guess |
| **Reach isn't scored** | a business that's hard to find is still a lead; reach only decides how to contact it |
| **Idempotent re-runs** (running twice gives the same result as once) | upserts on the map ID, status guards on decisions, and duplicate taps refused |
| **Compliance first** | business facts only and no profiles of people; any future outreach follows US rules (CAN-SPAM: honest sender and subject, a real postal address, a working opt-out) |

## What happened during the build

Real data changed the plan, and each change was logged:
- **Keys:** chains share a website, so leads are keyed on the map ID, not the domain.
- **Search shape:** a 40 km circle timed out; a bounding box works.
- **Calibration, v0.1 to v0.3:** the first rubric ignored working websites (8 of 10 test leads came out "possibly closed"); then missing map data was treated as closed; then missing information was scored as a "no". Each round was a logged reset with every old score kept.
- **Reliability gaps found and fixed:** a stall when nothing was left to audit (gates added), scoring running twice (audit made one straight path), a re-run wiping a hand-added website (manual data protected), a live query broken by an edit that a saved-data test couldn't see (rule: test live connections live).
- **Privacy:** before publishing, a scan found real phone numbers, emails and map contributors' usernames in the test data. A sharing standard and 2 independent leak checks now run on every build.
- **Errors planned for:** a broken line in the main map query sent every live run to the mirror, which timed out (http 504). The error alert named the exact step, the line was fixed the same day, and the next live run found 39 businesses.

## Results (measured in testing, not projected)

- **Live run, 20 October:** 39 businesses found in the Austin area, 4 new, 12 excluded as chains, closed or off-niche. A brand-new studio went all the way from the map to a scored card on my phone.
- **Across the test set:** every active lead scored on rubric v0.3, with warm leads and "check this" holds carded and cold leads summarized once.
- **Reliability:** duplicate and stale taps refused in testing; the error alert fired within a minute of a deliberate break; live mining re-runs created no duplicates.
- **Public:** github.com/anruops/sol-lead-engine with a sanitized workflow, migrations, the Python scoring service and tests, and generated documentation.

*Time saved and revenue impact are not claimed: those need a real client deployment to measure.*

## What's next

v2 adds 2 things: a slow-site signal (how long a site takes to load, because a slow page loses a customer before they book), and proposal drafting, where an approved lead's card becomes a draft proposal built from its own audit, which I review before anything is sent. Finding missing websites and working out why a site looks off (a rebrand, a move, a closure) stay manual on purpose: that research is the part of the review gate where a person sees what a rule can't. Outreach, reply handling and an optional hand-off to the onboarding system (LUNA) come after that.

## How AI was used

Claude was my guide and reviewer: explaining options, drafting code and documents, and reviewing my work in controlled tests. I built and wired every node, ran every test, and made every scope and design decision. The scoring rules are mine and explainable line by line.
