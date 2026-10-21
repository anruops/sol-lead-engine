# SOL Lead Engine · System Guide (General Edition)

*v1.0 · rubric v0.3 · 58 working nodes · generated 2026-10-22 from the live n8n export by `tools/build_docs.py`.*

> **Living document.** Regenerated from the workflow itself, so it always matches what runs. Sections marked *changes with the build* are edited by the generator, not by hand.

---

## What this system does

SOL Lead Engine finds established local businesses that customers struggle to reach online, audits each website like a frustrated customer, scores how much that is costing them with deterministic rules, and keeps a human in the loop: the engine gathers the facts and lays them out on a Telegram card, and a person verifies them, looks at the business the way its customers would, and decides what happens next. Cold leads arrive as 1 daily summary, and every decision is written once to an append-only log.

## How to read the canvas

There are **3 paths** on 1 canvas, each with its own trigger:

| Path | Trigger | What it does |
|---|---|---|
| Main path | Daily Run (8:00 am Austin time) | find → clean → audit → score → cards and cold summary |
| Poll Taps path | every minute | read your button taps and replies → decide → update the card |
| Error lane | any failed published run | tell you what broke and where |

Every node below says **where it sits** (its path, lane, what feeds it and where it goes) and **why it exists**.

## Lane map *(changes with the build)*

| Path | Lane | Nodes, in order |
|---|---|---|
| Main path | 0 · Start | Daily Run → Config → Search Area → Live or Fixture? |
| Main path | 1 · Mining | OSM Fixture → OSM Fetch → OSM Fetch (Mirror) → OSM OK? → Mining Failed |
| Main path | 2 · Refinery | One per Place → Normalize → Upsert Leads → Log Mining Run |
| Main path | 3 · Audit | Next Batch → Anything to Audit? → Visit Website → Audit Signals → Visit Contact Page → Merge Contact → Save Audit |
| Main path | 4 · Score | Score Batch → Anything to Score? → Score → Save Score → Log Score Run |
| Main path | 5a · Review cards | Review Batch → Build Card → Needs Check? → Send Needs-Check Card → Send Review Card → Mark Sent |
| Main path | Cold summary | Cold Batch → Build Summary → Send Summary → Mark Summarized |
| Poll Taps path | 5b · Read taps | Poll Taps → Get Offset → Get Updates → Any Updates? → Save Offset → One per Update → Parse Tap → Route |
| Poll Taps path | Button taps | Is Add Website? → Ask for URL → Answer Add Website → Write Decision → Decided? → Edit Card → Answer Tap → Answer Stale |
| Poll Taps path | URL replies | Save Website → Website Saved? → Edit Old Card → Confirm Website → Reply Invalid |
| Error lane | Error lane | Error Trigger → Error Alert |

---

## Main path

## Lane 0 · Start

*Starts the daily run and holds every setting you change to point the engine somewhere new.*

### 1 · Daily Run

*Schedule Trigger · Main path · Lane 0 · Start*

**Where it sits.** From: (trigger, starts the path) · To: → Config

**Why it exists.** Starts the main path every day at 8:00 am Austin time (America/Chicago), the market the engine audits. Click Execute on it to run the same path by hand.

| Setting | Value |
|---|---|
| rule.interval[0].triggerAtHour | `8` |

### 2 · Config

*Edit Fields (Set) · Main path · Lane 0 · Start*

**Where it sits.** From: Daily Run · To: → Search Area

**Why it exists.** The one place you edit: area (city, lat, lon, radius), niche keywords, country, batch size, test mode, and the Telegram chat for cards.

| Setting | Value |
|---|---|
| assignments.assignments › city | `Austin` |
| assignments.assignments › lat | `30.2672` |
| assignments.assignments › lon | `-97.7431` |
| assignments.assignments › radius_m | `40000` |
| assignments.assignments › niche | `yoga\|pilates` |
| assignments.assignments › country | `US` |
| assignments.assignments › batch_size | `10` |
| assignments.assignments › use_fixture | `False` |
| assignments.assignments › review_chat_id | `YOUR_TELEGRAM_CHAT_ID` |

### 3 · Search Area

*Edit Fields (Set) · Main path · Lane 0 · Start*

**Where it sits.** From: Config · To: → Live or Fixture?

**Why it exists.** Turns the center point and radius_m into a north/south/east/west box, each edge radius_m from the center (so the corners reach about 1.4 times further), because a box query is fast and a radius query timed out.

| Setting | Value |
|---|---|
| assignments.assignments › south | `={{ ($json.lat - $json.radius_m / 111320).toFixed(4) }}` |
| assignments.assignments › north | `={{ ($json.lat + $json.radius_m / 111320).toFixed(4) }}` |
| assignments.assignments › west | `={{ ($json.lon - $json.radius_m / (111320 * Math.cos($json.lat * Math.PI / 180))).toFixed(4) }}` |
| assignments.assignments › east | `={{ ($json.lon + $json.radius_m / (111320 * Math.cos($json.lat * Math.PI / 180))).toFixed(4) }}` |
| includeOtherFields | `True` |

### 4 · Live or Fixture?

*IF · Main path · Lane 0 · Start*

**Where it sits.** From: Search Area · To: true → OSM Fixture · false → OSM Fetch

**Why it exists.** use_fixture true sends the run to the saved test set, false to live OpenStreetMap, so demos never depend on a busy public server.

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `strict` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ $json.use_fixture }}  boolean → true` |
| conditions.combinator | `and` |

## Lane 1 · Mining

*Finds every business on OpenStreetMap that matches the niche inside the search area.*

### 5 · OSM Fixture

*Code (JavaScript) · Main path · Lane 1 · Mining*

**Where it sits.** From: Live or Fixture? (true) · To: → OSM OK?

**Why it exists.** A saved set of 36 Austin studios in the exact shape OpenStreetMap returns, for safe repeatable tests.

<details><summary>Code</summary>

```javascript
const elements = [
  {
    "type": "node",
    "id": 599493144,
    "lat": 30.3984426,
    "lon": -97.7492355,
    "timestamp": "2020-01-12T03:10:46Z",
    "tags": {
      "leisure": "sports_centre",
      "name": "Sunstone Yoga",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": 2527535393,
    "lat": 30.3510432,
    "lon": -97.7192825,
    "timestamp": "2025-11-23T16:08:37Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "1308",
      "addr:postcode": "78757",
      "addr:state": "TX",
      "addr:street": "West Anderson Lane",
      "addr:unit": "A",
      "leisure": "fitness_centre",
      "name": "Studio Satya",
      "phone": "SAMPLE_PHONE_1",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_1"
    }
  },
  {
    "type": "node",
    "id": 2705156688,
    "lat": 30.4997644,
    "lon": -97.8134229,
    "timestamp": "2024-06-27T08:19:59Z",
    "tags": {
      "addr:city": "Cedar Park",
      "addr:housenumber": "930",
      "addr:postcode": "78613",
      "addr:street": "S Bell Blvd., Suite 301",
      "leisure": "fitness_centre",
      "name": "Breath and Balance Bodyworks",
      "note": "Private Yoga Instruction",
      "payment:litecoin": "yes",
      "phone": "SAMPLE_PHONE_2",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_2"
    }
  },
  {
    "type": "node",
    "id": 3764021161,
    "lat": 30.26587,
    "lon": -97.741632,
    "timestamp": "2015-10-22T16:31:11Z",
    "tags": {
      "leisure": "fitness_centre",
      "name": "Wanderlust Yoga",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": 3825243606,
    "lat": 30.260472,
    "lon": -97.734817,
    "timestamp": "2025-02-01T19:44:50Z",
    "tags": {
      "addr:housenumber": "913",
      "addr:street": "East Cesar Chavez Street",
      "coa:place_id": "1163135",
      "leisure": "fitness_centre",
      "name": "Black Swan Yoga",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": 3849776348,
    "lat": 30.2651252,
    "lon": -97.7455376,
    "timestamp": "2026-05-02T19:31:20Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "204",
      "addr:postcode": "78701",
      "addr:state": "TX",
      "addr:street": "Colorado Street",
      "branch": "Downtown Austin",
      "brand": "[solidcore]",
      "brand:wikidata": "Q124429271",
      "leisure": "fitness_centre",
      "name": "Solidcore",
      "phone": "SAMPLE_PHONE_3",
      "sport": "pilates"
    }
  },
  {
    "type": "node",
    "id": 3857693597,
    "lat": 30.270566,
    "lon": -97.7558102,
    "timestamp": "2026-05-20T06:37:27Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "1011",
      "addr:postcode": "78703",
      "addr:state": "TX",
      "addr:street": "West 5th Street",
      "addr:unit": "140",
      "brand": "Jetset Pilates",
      "leisure": "fitness_centre",
      "name": "Jetset Pilates",
      "not:brand:wikidata": "Q109328844",
      "phone": "SAMPLE_PHONE_4",
      "sport": "pilates",
      "website": "SAMPLE_WEBSITE_3"
    }
  },
  {
    "type": "node",
    "id": 5771447958,
    "lat": 30.2304202,
    "lon": -97.7982812,
    "timestamp": "2026-04-07T03:59:24Z",
    "tags": {
      "leisure": "fitness_centre",
      "name": "Flow Yoga",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": 5771447970,
    "lat": 30.2313218,
    "lon": -97.8014382,
    "timestamp": "2018-07-19T18:37:39Z",
    "tags": {
      "leisure": "fitness_centre",
      "name": "Black Swan Yoga",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": 6348354559,
    "lat": 30.5503066,
    "lon": -97.8532955,
    "timestamp": "2023-02-27T16:32:36Z",
    "tags": {
      "addr:city": "Leander",
      "addr:housenumber": "1904",
      "addr:postcode": "78641",
      "addr:state": "TX",
      "addr:street": "South Bagdad Road",
      "addr:unit": "4",
      "check_date": "2023-02-27",
      "leisure": "fitness_centre",
      "name": "Trybe Yoga",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": 6455846385,
    "lat": 30.3152599,
    "lon": -97.7338229,
    "timestamp": "2024-01-16T01:13:49Z",
    "tags": {
      "brand": "CorePower Yoga",
      "brand:wikidata": "Q21015663",
      "leisure": "fitness_centre",
      "name": "CorePower Yoga",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": 8064257679,
    "lat": 30.533445,
    "lon": -97.8196367,
    "timestamp": "2022-06-26T03:21:53Z",
    "tags": {
      "brand": "Club Pilates",
      "brand:wikidata": "Q109328844",
      "leisure": "fitness_centre",
      "name": "Club Pilates",
      "sport": "pilates"
    }
  },
  {
    "type": "node",
    "id": 8218109708,
    "lat": 30.4952162,
    "lon": -97.6664257,
    "timestamp": "2023-10-18T22:43:31Z",
    "tags": {
      "addr:city": "Round Rock",
      "addr:housenumber": "1011",
      "addr:postcode": "78664",
      "addr:state": "TX",
      "addr:street": "Gattis School Road",
      "addr:unit": "109",
      "leisure": "fitness_centre",
      "name": "Round Rock Krav Maga & Kick Boxing",
      "phone": "SAMPLE_PHONE_5",
      "sport": "fitness;kickboxing;krav_maga;yoga",
      "website": "SAMPLE_WEBSITE_4"
    }
  },
  {
    "type": "node",
    "id": 8881107227,
    "lat": 30.3251178,
    "lon": -97.7152592,
    "timestamp": "2022-12-11T18:12:52Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "109",
      "addr:postcode": "78752",
      "addr:state": "TX",
      "addr:street": "Jacob Fontaine Lane",
      "addr:unit": "800",
      "leisure": "fitness_centre",
      "name": "My Vinyasa Practice",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": 8936903699,
    "lat": 30.2987668,
    "lon": -97.701392,
    "timestamp": "2023-03-07T06:54:50Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "2112",
      "addr:postcode": "78723",
      "addr:state": "TX",
      "addr:street": "Robert Browning Street",
      "email": "SAMPLE_EMAIL_1",
      "leisure": "fitness_centre",
      "name": "Ashtanga Yoga Austin",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_5"
    }
  },
  {
    "type": "node",
    "id": 9027639852,
    "lat": 30.3482173,
    "lon": -97.3708591,
    "timestamp": "2023-05-14T21:17:50Z",
    "tags": {
      "addr:city": "Elgin",
      "addr:housenumber": "28",
      "addr:postcode": "78621",
      "addr:state": "TX",
      "addr:street": "North Main Street",
      "check_date": "2023-05-14",
      "leisure": "fitness_centre",
      "name": "Body + Shine Wellness",
      "phone": "SAMPLE_PHONE_6",
      "sport": "yoga;pilates",
      "website": "SAMPLE_WEBSITE_6",
      "wheelchair": "yes"
    }
  },
  {
    "type": "node",
    "id": 9947713718,
    "lat": 30.351352,
    "lon": -97.7215105,
    "timestamp": "2022-08-11T15:33:48Z",
    "tags": {
      "addr:postcode": "78757",
      "leisure": "fitness_centre",
      "name": "Black Swan Yoga"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_7,
    "lat": 30.2153289,
    "lon": -97.8339027,
    "timestamp": "2023-01-18T21:47:13Z",
    "tags": {
      "addr:city": "Austin",
      "addr:country": "US",
      "addr:housenumber": "3601",
      "addr:postcode": "78749",
      "addr:state": "TX",
      "addr:street": "West William Cannon Drive",
      "addr:unit": "100",
      "leisure": "fitness_centre",
      "name": "B Pilates"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_8,
    "lat": 30.3233272,
    "lon": -97.7270069,
    "timestamp": "2023-03-07T01:37:24Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "5501",
      "addr:postcode": "78751",
      "addr:state": "TX",
      "addr:street": "North Lamar Boulevard",
      "addr:unit": "C111",
      "leisure": "fitness_centre",
      "name": "Body Collective",
      "phone": "SAMPLE_PHONE_9",
      "sport": "yoga;dance;dancing;pilates;barre;kizomba",
      "website": "SAMPLE_WEBSITE_7"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_10,
    "lat": 30.2945795,
    "lon": -97.8240079,
    "timestamp": "2023-04-16T00:12:47Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "5604",
      "addr:postcode": "78746",
      "addr:state": "TX",
      "addr:street": "Bee Caves Road",
      "check_date": "2023-04-15",
      "email": "SAMPLE_EMAIL_2",
      "leisure": "fitness_centre",
      "name": "Wild Heart Yoga",
      "opening_hours": "Mo-Fr 07:00-21:00; Sa-Su 09:00-17:00",
      "phone": "SAMPLE_PHONE_11",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_8"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_12,
    "lat": 30.0871114,
    "lon": -97.8298144,
    "timestamp": "2023-08-30T23:00:43Z",
    "tags": {
      "brand": "Club Pilates",
      "brand:wikidata": "Q109328844",
      "leisure": "fitness_centre",
      "name": "Club Pilates",
      "sport": "pilates"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_13,
    "lat": 30.2742602,
    "lon": -97.7992642,
    "timestamp": "2023-12-23T20:54:39Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "3300",
      "addr:postcode": "78746",
      "addr:state": "TX",
      "addr:street": "Bee Caves Road",
      "addr:unit": "745",
      "check_date": "2023-12-23",
      "email": "SAMPLE_EMAIL_3",
      "leisure": "fitness_centre",
      "name": "Pilates Movement Studio",
      "phone": "SAMPLE_PHONE_14",
      "website": "SAMPLE_WEBSITE_9",
      "wheelchair": "yes"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_15,
    "lat": 30.4763818,
    "lon": -97.8409929,
    "timestamp": "2024-04-08T09:05:14Z",
    "tags": {
      "addr:city": "Cedar Park",
      "addr:housenumber": "2051",
      "addr:postcode": "78613",
      "addr:state": "TX",
      "addr:street": "Cypress Creek Road",
      "addr:unit": "G",
      "email": "SAMPLE_EMAIL_4",
      "leisure": "fitness_centre",
      "name": "Ying Yoga",
      "phone": "SAMPLE_PHONE_16",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_10"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_17,
    "lat": 29.9960511,
    "lon": -98.0968731,
    "timestamp": "2024-10-11T14:14:10Z",
    "tags": {
      "leisure": "fitness_centre",
      "name": "Wimberley Pilates"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_18,
    "lat": 30.4793944,
    "lon": -97.8293102,
    "timestamp": "2025-01-04T07:18:53Z",
    "tags": {
      "addr:city": "Cedar Park",
      "addr:housenumber": "2015",
      "addr:postcode": "78613",
      "addr:state": "TX",
      "addr:street": "Little Elm Trail",
      "addr:unit": "500",
      "check_date": "2025-01-04",
      "leisure": "fitness_centre",
      "name": "Fifty/50 Pilates",
      "opening_hours": "Mo-Fr 07:00-20:00; Sa-Su 08:00-15:00",
      "phone": "SAMPLE_PHONE_19",
      "sport": "pilates",
      "website": "SAMPLE_WEBSITE_11"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_20,
    "lat": 30.2983374,
    "lon": -97.7058796,
    "timestamp": "2024-11-17T03:20:51Z",
    "tags": {
      "addr:city": "Austin",
      "addr:postcode": "78723",
      "addr:state": "TX",
      "addr:unit": "101",
      "brand": "CorePower Yoga",
      "brand:wikidata": "Q21015663",
      "leisure": "fitness_centre",
      "name": "CorePower Yoga",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_21,
    "lat": 30.253113,
    "lon": -97.7636248,
    "timestamp": "2025-03-28T21:31:11Z",
    "tags": {
      "check_date:opening_hours": "2025-03-28",
      "leisure": "fitness_centre",
      "name": "Pure Pilates Austin",
      "opening_hours:signed": "no",
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_22,
    "lat": 30.2658766,
    "lon": -97.7438805,
    "timestamp": "2026-02-12T05:04:20Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "3145",
      "addr:postcode": "78704",
      "addr:state": "TX",
      "addr:street": "Congress Avenue",
      "leisure": "fitness_centre",
      "name": "Yoga Hom",
      "opening_hours": "Mo-Th 06:00-20:00; Fr 06:00-17:30; Sa 08:00-14:00; Su 09:30-14:00",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_13"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_23,
    "lat": 30.2639097,
    "lon": -97.7325762,
    "timestamp": "2025-11-26T20:22:36Z",
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "1011",
      "addr:postcode": "78702",
      "addr:state": "TX",
      "addr:street": "East 5th Street",
      "addr:unit": "130",
      "brand": "Club Pilates",
      "brand:wikidata": "Q109328844",
      "leisure": "fitness_centre",
      "name": "Club Pilates",
      "sport": "pilates"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_24,
    "lat": 30.5294431,
    "lon": -97.8141821,
    "timestamp": "2025-12-26T07:53:23Z",
    "tags": {
      "addr:city": "Cedar Park",
      "addr:housenumber": "1335",
      "addr:postcode": "78613",
      "addr:state": "TX",
      "addr:street": "East Whitestone Boulevard",
      "addr:unit": "D185",
      "brand": "CorePower Yoga",
      "brand:wikidata": "Q21015663",
      "check_date": "2025-12-25",
      "leisure": "fitness_centre",
      "name": "CorePower Yoga",
      "opening_hours": "Mo-Fr 06:00-20:30; Sa-Su 07:30-18:00",
      "sport": "yoga"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_25,
    "lat": 30.1718172,
    "lon": -97.7863234,
    "timestamp": "2026-04-07T04:10:14Z",
    "tags": {
      "leisure": "fitness_centre",
      "name": "Flow Yoga"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_26,
    "lat": 30.447464,
    "lon": -97.7871422,
    "timestamp": "2026-06-19T08:50:45Z",
    "tags": {
      "check_date": "2026-06-04",
      "leisure": "fitness_centre",
      "name": "Anahata Yoga Sanctuary",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_14"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_27,
    "lat": 30.2792606,
    "lon": -97.7595565,
    "timestamp": "2026-08-06T02:25:20Z",
    "tags": {
      "addr:housenumber": "1013",
      "addr:postcode": "78703",
      "addr:street": "West Lynn Street",
      "check_date": "2026-08-05",
      "leisure": "fitness_centre",
      "name": "Activ8 Studio",
      "phone": "SAMPLE_PHONE_28",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_15"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_29,
    "lat": 30.2717035,
    "lon": -97.7593163,
    "timestamp": "2026-08-07T03:38:45Z",
    "tags": {
      "addr:housenumber": "1213",
      "addr:postcode": "78703",
      "addr:street": "West 5th Street",
      "check_date": "2026-08-06",
      "leisure": "fitness_centre",
      "name": "Black Swan Yoga",
      "phone": "SAMPLE_PHONE_30",
      "sport": "yoga",
      "website": "SAMPLE_WEBSITE_16"
    }
  },
  {
    "type": "node",
    "id": SAMPLE_PHONE_31,
    "lat": 30.2745999,
    "lon": -97.7640866,
    "timestamp": "2026-09-26T23:37:26Z",
    "tags": {
      "addr:housenumber": "1614",
      "addr:postcode": "78703",
      "addr:street": "West 5th Street",
      "check_date": "2026-09-26",
      "leisure": "fitness_centre",
      "name": "Haus of B",
      "sport": "yoga"
    }
  },
  {
    "type": "way",
    "id": 382713727,
    "timestamp": "2023-10-04T01:45:53Z",
    "center": {
      "lat": 30.2872383,
      "lon": -97.7012325
    },
    "nodes": [
      3859335482,
      3859335467,
      3859335488,
      3859335501,
      3859335482
    ],
    "tags": {
      "addr:city": "Austin",
      "addr:housenumber": "3317",
      "addr:postcode": "78723",
      "addr:state": "TX",
      "addr:street": "Manor Road",
      "building": "yes",
      "height": "5.4",
      "leisure": "fitness_centre",
      "name": "Dharma Yoga",
      "sport": "yoga"
    }
  }
]
return [{ json: { elements } }];
```

</details>

### 6 · OSM Fetch

*HTTP Request · Main path · Lane 1 · Mining*

**Where it sits.** From: Live or Fixture? (false) · To: success → OSM OK? · error → OSM Fetch (Mirror)

**Why it exists.** Asks the main Overpass server for every place matching the niche keywords inside the box. Retries 3 times before giving up.

**Settings that matter.** on error: error output · retry: 3 tries, 5000 ms apart

| Setting | Value |
|---|---|
| url | `https://overpass-api.de/api/interpreter` |
| sendQuery | `True` |
| queryParameters.parameters › data | `=[out:json][timeout:180][bbox:{{ $json.south }},{{ $json.west }},{{ $json.north }},{{ $json.east }}]; (   nwr["sport"~"{{ $json.niche }}"];   nwr["leisure"="fitness_centre"]["name"~"{{ $json.niche }}"…` |
| sendHeaders | `True` |
| headerParameters.parameters › User-Agent | `RECON/0.1 (n8n lead research)` |
| options.timeout | `200000` |

### 7 · OSM Fetch (Mirror)

*HTTP Request · Main path · Lane 1 · Mining*

**Where it sits.** From: OSM Fetch (error) · To: success → OSM OK? · error → Mining Failed

**Why it exists.** If the main server fails, asks a second Overpass server with the same query.

**Settings that matter.** on error: error output · retry: 3 tries, 5000 ms apart

| Setting | Value |
|---|---|
| url | `https://overpass.private.coffee/api/interpreter` |
| sendQuery | `True` |
| queryParameters.parameters › data | `=[out:json][timeout:180][bbox:{{ $json.south }},{{ $json.west }},{{ $json.north }},{{ $json.east }}]; (   nwr["sport"~"{{ $json.niche }}"];   nwr["leisure"="fitness_centre"]["name"~"{{ $json.niche }}"…` |
| sendHeaders | `True` |
| headerParameters.parameters › User-Agent | `RECON/0.1 (n8n lead research)` |
| options.timeout | `200000` |

### 8 · OSM OK?

*IF · Main path · Lane 1 · Mining*

**Where it sits.** From: OSM Fetch (success), OSM Fetch (Mirror) (success), OSM Fixture · To: true → One per Place · false → Mining Failed

**Why it exists.** Checks the answer is real data. Overpass reports timeouts as a "success" with a remark, so this catches the fake success.

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `loose` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ !$json.remark && ($json.elements?.length ?? 0) > 0 }}  boolean → true  0` |
| conditions.combinator | `and` |
| looseTypeValidation | `True` |

### 9 · Mining Failed

*Stop and Error · Main path · Lane 1 · Mining*

**Where it sits.** From: OSM OK? (false), OSM Fetch (Mirror) (error) · To: (end of branch)

**Why it exists.** Stops the run loudly (and fires the error lane) instead of carrying on with nothing.

| Setting | Value |
|---|---|
| errorMessage | `=Mining failed for {{ $('Search Area').item.json.city }} \| http: {{ $json.error?.status ?? '-' }} \| remark: {{ $json.remark ?? 'none' }} \| elements: {{ $json.elements?.length ?? 0 }} \| reply: {{ J…` |

## Lane 2 · Refinery

*Turns raw map data into clean lead records, flags chains and closed places, and saves without duplicates.*

### 10 · One per Place

*Split Out · Main path · Lane 2 · Refinery*

**Where it sits.** From: OSM OK? (true) · To: → Normalize

**Why it exists.** Splits the map answer into one item per place.

| Setting | Value |
|---|---|
| fieldToSplitOut | `elements` |

### 11 · Normalize

*Code (JavaScript) · Main path · Lane 2 · Refinery*

**Where it sits.** From: One per Place · To: → Upsert Leads

**Why it exists.** Builds the lead record: map ID as the key, domain, phone format, free-email flag, location count, niche label from Config, and an exclude reason (no name, closed, chain, off-niche).

<details><summary>Code</summary>

```javascript
const area = $('Search Area').first().json;
const FREEMAIL = ['gmail.com','icloud.com','yahoo.com','hotmail.com','outlook.com','aol.com','me.com','live.com'];
const NICHE = new RegExp(area.niche, 'i');   // niche keywords come from Config, e.g. "yoga|pilates"
const NICHE_TERMS = area.niche.split('|').map(s => s.trim().toLowerCase()).filter(Boolean);

const pick = (t, ...keys) => {
  for (const k of keys) if (t[k]) return String(t[k]).trim();
  return null;
};

// plain-text domain match (the URL helper isn't available in this sandbox)
const domainOf = (url) => {
  if (!url) return null;
  const m = String(url).toLowerCase().match(/^(?:[a-z]+:\/\/)?(?:www\.)?([^\/:?#]+)/);
  return m ? m[1] : null;
};

const phoneOf = (raw) => {
  if (!raw) return null;
  const first = raw.split(';')[0].trim();
  const digits = first.replace(/\D/g, '');
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  return first;
};

const items = $input.all();

// how many times each name appears in this batch (unbranded chains)
const nameCount = {};
for (const { json: e } of items) {
  const n = (e.tags?.name || '').trim().toLowerCase();
  if (n) nameCount[n] = (nameCount[n] || 0) + 1;
}

return items.map(({ json: e }) => {
  const t = e.tags || {};
  const name = pick(t, 'name');
  const sports = (t.sport || '').toLowerCase().split(';').map(s => s.trim()).filter(Boolean);
  const text = `${sports.join(' ')} ${name || ''}`.toLowerCase();
  // label = every Config keyword this place matches, joined with "_" (e.g. yoga_pilates)
  const niche = NICHE_TERMS.filter(k => text.includes(k)).join('_') || NICHE_TERMS[0];

  const offNiche = !NICHE.test(name || '') && sports.length > 0 && !NICHE.test(sports[0]);

  const website = pick(t, 'website', 'contact:website', 'url');
  const domain = domainOf(website);
  const email = pick(t, 'email', 'contact:email');
  const emailDomain = email ? email.split('@')[1]?.toLowerCase() : null;
  const email_type = !email ? null
    : FREEMAIL.includes(emailDomain) ? 'freemail'
    : emailDomain === domain ? 'business' : 'other';

  const socials = Object.fromEntries(
    ['facebook', 'instagram', 'tiktok', 'youtube', 'twitter']
      .map(s => [s, pick(t, `contact:${s}`, s)])
      .filter(([, v]) => v)
  );

  const closed = Object.keys(t).some(k => /^(disused|abandoned|was|demolished|removed):/.test(k))
    || t.opening_hours === 'closed' || !!t.end_date;
  const brand = pick(t, 'brand');
  const location_count = name ? nameCount[name.toLowerCase()] : 1;

  const exclude_reason = !name ? 'no_name'
    : closed ? 'closed'
    : brand ? 'chain'
    : offNiche ? 'off_niche'
    : null;

  const street = [t['addr:housenumber'], t['addr:street']].filter(Boolean).join(' ');

  return { json: {
    lead_key: `osm:${e.type}/${e.id}`,
    source: 'osm',
    source_id: `${e.type}/${e.id}`,
    business_name: name,
    niche,
    address: [street, t['addr:unit']].filter(Boolean).join(', ') || null,
    city: t['addr:city'] || null,
    region: t['addr:state'] || null,
    postcode: t['addr:postcode'] || null,
    country: t['addr:country'] || area.country,
    lat: e.lat ?? e.center?.lat ?? null,
    lon: e.lon ?? e.center?.lon ?? null,
    phone: phoneOf(pick(t, 'phone', 'contact:phone')),
    website_url: website,
    website_domain: domain,
    email,
    email_type,
    socials,
    opening_hours: t.opening_hours || null,
    osm_last_edit: e.timestamp || null,
    brand,
    multi_location: location_count > 1,
    location_count,
    exclude_reason,
    source_batch: `${area.city}-${$now.toFormat('yyyy-MM-dd')}`,
    raw_tags: t,
  }};
});
```

</details>

### 12 · Upsert Leads

*Postgres · Main path · Lane 2 · Refinery*

**Where it sits.** From: Normalize · To: → Log Mining Run

**Why it exists.** Saves to Neon keyed on the map ID. Re-running never duplicates, never changes a lead's status, and never overwrites a website you added by hand.

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryBatching | `transaction` |
| options.queryReplacement | `={{ [ $json.lead_key, $json.source, $json.source_id, $json.business_name, $json.niche, $json.address, $json.city, $json.region, $json.postcode, $json.country, $json.lat, $json.lon, $json.phone, $json.…` |

<details><summary>SQL</summary>

```sql
INSERT INTO leads_master (
  lead_key, source, source_id, business_name, target_niche, address, city, region,
  postcode, country, lat, lon, phone, website_url, website_domain, email, email_type,
  socials, opening_hours, osm_last_edit, brand, multi_location, location_count,
  exclude_reason, raw_tags, source_batch, automation_status
) VALUES (
  $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17,
  $18::jsonb, $19, $20::timestamptz, $21, $22, $23, $24, $25::jsonb, $26,
  (CASE WHEN $24::text IS NULL THEN 'new' ELSE 'excluded' END)::lead_state
)
ON CONFLICT (lead_key) DO UPDATE SET
  business_name  = EXCLUDED.business_name,
  target_niche   = EXCLUDED.target_niche,
  address        = EXCLUDED.address,
  city           = EXCLUDED.city,
  region         = EXCLUDED.region,
  postcode       = EXCLUDED.postcode,
  lat            = EXCLUDED.lat,
  lon            = EXCLUDED.lon,
  phone          = EXCLUDED.phone,
  website_url    = CASE WHEN leads_master.website_source = 'manual' THEN leads_master.website_url    ELSE EXCLUDED.website_url    END,
  website_domain = CASE WHEN leads_master.website_source = 'manual' THEN leads_master.website_domain ELSE EXCLUDED.website_domain END,
  email          = EXCLUDED.email,
  email_type     = EXCLUDED.email_type,
  socials        = EXCLUDED.socials,
  opening_hours  = EXCLUDED.opening_hours,
  osm_last_edit  = EXCLUDED.osm_last_edit,
  brand          = EXCLUDED.brand,
  multi_location = EXCLUDED.multi_location,
  location_count = EXCLUDED.location_count,
  exclude_reason = EXCLUDED.exclude_reason,
  raw_tags       = EXCLUDED.raw_tags
RETURNING lead_key, business_name, automation_status, exclude_reason, (xmax = 0) AS inserted;
```

</details>

### 13 · Log Mining Run

*Postgres · Main path · Lane 2 · Refinery*

**Where it sits.** From: Upsert Leads · To: → Next Batch

**Why it exists.** Records what was searched, how many came back, how many were excluded, and which server answered.

**Settings that matter.** execute once

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ [ $('Normalize').first().json.source_batch, $('Search Area').first().json.city, $('Search Area').first().json.niche, $('OSM Fixture').isExecuted ? 'fixture' : ($('OSM Fetch (Mirror)').isExecuted ?…` |

<details><summary>SQL</summary>

```sql
INSERT INTO mining_runs (source_batch, city, niche, endpoint, found, new_leads, excluded, finished_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, now())
RETURNING id, source_batch, found, new_leads, excluded;
```

</details>

## Lane 3 · Audit

*Visits each website the way a customer would and records what works and what does not.*

### 14 · Next Batch

*Postgres · Main path · Lane 3 · Audit*

**Where it sits.** From: Log Mining Run · To: → Anything to Audit?

**Why it exists.** Takes up to batch_size leads still marked new, oldest first. Always outputs, so the gate below can see "nothing to do".

**Settings that matter.** retry: 3 tries, 5000 ms apart · always output data · execute once

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ [ $('Config').first().json.batch_size ] }}` |

<details><summary>SQL</summary>

```sql
SELECT lead_key, business_name, target_niche, website_url, website_domain, country
FROM leads_master
WHERE automation_status = 'new'
ORDER BY created_at, id
LIMIT $1;
```

</details>

### 15 · Anything to Audit?

*IF · Main path · Lane 3 · Audit*

**Where it sits.** From: Next Batch · To: true → Visit Website · false → Score Batch

**Why it exists.** Gate: leads waiting go to the audit; nothing waiting skips straight to scoring.

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `strict` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ !!$json.lead_key }}  boolean → true` |
| conditions.combinator | `and` |

### 16 · Visit Website

*HTTP Request · Main path · Lane 3 · Audit*

**Where it sits.** From: Anything to Audit? (true) · To: → Audit Signals

**Why it exists.** Loads the homepage once (1 every 2 seconds, 10 second timeout, never stops the run). No website means an empty request that fails safely.

**Settings that matter.** on error: continue · retry: 2 tries, 3000 ms apart

| Setting | Value |
|---|---|
| url | `={{ $json.website_url }}` |
| sendHeaders | `True` |
| headerParameters.parameters › User-Agent | `Mozilla/5.0 (compatible; RECON-audit/0.1)` |
| options.batching.batch.batchSize | `1` |
| options.batching.batch.batchInterval | `2000` |
| options.response.response.fullResponse | `True` |
| options.response.response.neverError | `True` |
| options.response.response.responseFormat | `text` |
| options.timeout | `10000` |

### 17 · Audit Signals

*Code (JavaScript) · Main path · Lane 3 · Audit*

**Where it sits.** From: Visit Website · To: → Visit Contact Page

**Why it exists.** Reads the page like a customer: HTTPS, mobile-ready, copyright year, booking provider, contact form, emails, socials, platform, and the contact page link.

| Setting | Value |
|---|---|
| mode | `runOnceForEachItem` |

<details><summary>Code</summary>

```javascript
const lead = $('Next Batch').item.json;
const res = $input.item.json;
const year = new Date().getFullYear();
const base = { lead_key: lead.lead_key, business_name: lead.business_name, audited_at: new Date().toISOString() };

// 1. No website on record
if (!lead.website_url) {
  return { json: { ...base, site_status: 'none', tags: ['needs_check'], audit_details: { reason: 'no website listed on the map' } } };
}
// 2. No answer at all (dead domain, timeout)
if (!res.statusCode) {
  return { json: { ...base, site_status: 'down', tags: [], audit_details: { reason: String(res.error?.message || res.error || 'no response').slice(0, 200) } } };
}
// 3. Answered with an error
const code = res.statusCode;
if ([401, 403, 429].includes(code)) {
  return { json: { ...base, site_status: 'blocked', tags: ['needs_check'], audit_details: { http_status: code, reason: 'site refused an automated visit' } } };
}
if (code >= 400) {
  return { json: { ...base, site_status: 'down', tags: [], audit_details: { http_status: code } } };
}

// 4. Page loaded: read it like a customer would
const html = String(res.data || res.body || '');
// clean = page without styles and code comments; text = roughly what a visitor reads
const clean = html.replace(/<style[\s\S]*?<\/style>/gi, ' ').replace(/<!--[\s\S]*?-->/g, ' ');
const text = clean.replace(/<script[\s\S]*?<\/script>/gi, ' ');

const pick = (re) => { const m = html.match(re); return m ? m[1].trim() : null; };
const domainOf = (u) => { if (!u) return null; const m = String(u).toLowerCase().match(/^(?:[a-z]+:\/\/)?(?:www\.)?([^\/:?#]+)/); return m ? m[1] : null; };

const declared = pick(/<link[^>]+rel=["']canonical["'][^>]*href=["']([^"']+)/i)
  || pick(/<link[^>]+href=["']([^"']+)["'][^>]*rel=["']canonical/i)
  || pick(/<meta[^>]+property=["']og:url["'][^>]*content=["']([^"']+)/i);
const declaredDomain = domainOf(declared);
const domainMismatch = !!(declaredDomain && lead.website_domain && declaredDomain !== lead.website_domain);

const https = (declared || lead.website_url).toLowerCase().startsWith('https://');
const mobileReady = /<meta[^>]+name=["']viewport["']/i.test(html);
const legacyFrameset = /<frameset|<frame\s/i.test(html);

const years = [...text.matchAll(/(?:©|&copy;|&#169;|copyright)[^<\d]{0,40}((?:19|20)\d{2})/gi)]
  .map(m => +m[1]).filter(y => y >= 1995 && y <= year + 1);
const copyrightYear = years.length ? Math.max(...years) : null;

const PROVIDERS = [
  ['Mindbody', /mindbodyonline|healcode|mindbody\.io/i], ['Momence', /momence\.com/i],
  ['Glofox', /glofox/i], ['Acuity', /acuityscheduling/i], ['Calendly', /calendly\.com/i],
  ['Vagaro', /vagaro\.com/i], ['WellnessLiving', /wellnessliving/i], ['Mariana Tek', /marianatek|mariana-tek/i],
  ['Zen Planner', /zenplanner/i], ['PunchPass', /punchpass/i], ['Walla', /hellowalla|walla\.app/i],
  ['Arketa', /arketa/i], ['bsport', /bsport\.io/i], ['Schedulicity', /schedulicity/i],
  ['Square Appointments', /squareup\.com\/appointments|square\.site/i], ['Wix Bookings', /book-online|wixbookings/i],
  ['Karmasoft', /karmasoft\.io/i], ['TeamUp', /goteamup/i], ['Pike13', /pike13/i], ['Union', /union\.fit/i],
  ['Eversports', /eversports/i], ['Momoyoga', /momoyoga/i], ['OfferingTree', /offeringtree/i],
  ['Bookwhen', /bookwhen/i], ['SimplyBook', /simplybook/i], ['Setmore', /setmore/i], ['Zingfit', /zingfit/i],
];
const bookingProvider = (PROVIDERS.find(([, re]) => re.test(clean)) || [null])[0];
const bookingPath = /href=["'][^"']*(book|schedule|class|reserve|timetable)[^"']*["']/i.test(clean);
const clicksToBook = bookingProvider ? 1 : (bookingPath ? 2 : null);

const hasContactForm = /<form[\s\S]*?<textarea/i.test(html);
const hasContactPage = /href=["'][^"']*contact[^"']*["']/i.test(html);
const clickToCall = /href=["']tel:/i.test(html);

const emails = [...new Set([...html.matchAll(/mailto:([^"'?\s>]+)/gi)].map(m => decodeURIComponent(m[1]).toLowerCase()))];
const socials = [...new Set([...clean.matchAll(/https?:\/\/(?:www\.)?(instagram\.com|facebook\.com|tiktok\.com|youtube\.com|x\.com|twitter\.com|linkedin\.com)\/(?!sharer|share|intent|dialog|plugins|\d{4}\/)[^"'\s<>]+/gi)].map(m => m[0]))];

const PLATFORMS = [['WordPress', /wp-content|wp-includes/i], ['Squarespace', /static1\.squarespace\.com|squarespace-cdn\.com/i],
  ['Wix', /wixstatic\.com|parastorage\.com/i], ['Webflow', /website-files\.com/i], ['Shopify', /cdn\.shopify\.com/i],
  ['GoDaddy', /img1\.wsimg\.com/i], ['Google Sites', /sites\.google\.com/i]];
const platform = (PLATFORMS.find(([, re]) => re.test(clean)) || [null])[0];
const newsletterTool = /list-manage|mailchimp/i.test(html) ? 'Mailchimp'
  : /klaviyo/i.test(html) ? 'Klaviyo' : /mailerlite/i.test(html) ? 'MailerLite' : null;

// contact page on the same site (URL() isn't available here, so plain string work)
const siteOrigin = (lead.website_url.match(/^https?:\/\/[^\/?#]+/i) || [''])[0];
const contactHref = pick(/href=["']([^"'#]*contact[^"'#]*)["']/i);
let contactUrl = null;
if (contactHref && !/^(mailto|tel):/i.test(contactHref)) {
  if (/^https?:\/\//i.test(contactHref)) {
    contactUrl = domainOf(contactHref) === domainOf(lead.website_url) ? contactHref : null;
  } else {
    contactUrl = siteOrigin + (contactHref.startsWith('/') ? '' : '/') + contactHref;
  }
}
const tags = [];
if (legacyFrameset) tags.push('legacy_site');
if (domainMismatch) tags.push('domain_mismatch');
if (legacyFrameset || html.length < 3000 || (platform === 'Wix' && !bookingProvider)) tags.push('needs_check');

return { json: {
  ...base,
  site_status: 'ok',
  final_url: declared,
  https,
  mobile_ready: mobileReady,
  copyright_year: copyrightYear,
  has_booking: !!bookingProvider,
  booking_provider: bookingProvider,
  has_contact_form: hasContactForm,
  emails_found: emails,
  contact_url: contactUrl,
  tags,
  audit_details: {
    http_status: code, page_title: pick(/<title[^>]*>([^<]*)/i), platform,
    clicks_to_book: clicksToBook, has_contact_page: hasContactPage, click_to_call: clickToCall,
    socials_found: socials, newsletter_tool: newsletterTool,
    legacy_frameset: legacyFrameset, declared_domain: declaredDomain, page_size: html.length,
  },
}};
```

</details>

### 18 · Visit Contact Page

*HTTP Request · Main path · Lane 3 · Audit*

**Where it sits.** From: Audit Signals · To: → Merge Contact

**Why it exists.** Loads the site's own contact page when there is one, same gentle settings.

**Settings that matter.** on error: continue · retry: 2 tries, 3000 ms apart

| Setting | Value |
|---|---|
| url | `={{ $json.contact_url }}` |
| sendHeaders | `True` |
| headerParameters.parameters › User-Agent | `Mozilla/5.0 (compatible; RECON-audit/0.1)` |
| options.batching.batch.batchSize | `1` |
| options.batching.batch.batchInterval | `2000` |
| options.response.response.fullResponse | `True` |
| options.response.response.neverError | `True` |
| options.response.response.responseFormat | `text` |
| options.timeout | `10000` |

### 19 · Merge Contact

*Code (JavaScript) · Main path · Lane 3 · Audit*

**Where it sits.** From: Visit Contact Page · To: → Save Audit

**Why it exists.** Adds emails, forms and phone links found on the contact page to the homepage findings.

| Setting | Value |
|---|---|
| mode | `runOnceForEachItem` |

<details><summary>Code</summary>

```javascript
const a = $('Audit Signals').item.json;
const res = $input.item.json;
const ok = res.statusCode && res.statusCode < 400;
const html = ok ? String(res.data || res.body || '') : '';
const plain = html.replace(/<script[\s\S]*?<\/script>/gi, ' ').replace(/<[^>]+>/g, ' ');

const mailto = [...html.matchAll(/mailto:([^"'?\s>]+)/gi)].map(m => decodeURIComponent(m[1]).toLowerCase());
const written = [...plain.matchAll(/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/gi)].map(m => m[0].toLowerCase())
  .filter(e => !/\.(png|jpe?g|gif|webp|svg)$/.test(e) && !/sentry|wixpress|example\./.test(e));
const emails = [...new Set([...(a.emails_found || []), ...mailto, ...written])];

return { json: {
  ...a,
  emails_found: emails,
  has_contact_form: a.has_contact_form || /<form[\s\S]*?<textarea/i.test(html),
  audit_details: {
    ...a.audit_details,
    click_to_call: a.audit_details.click_to_call || /href=["']tel:/i.test(html),
    contact_url: a.contact_url,
    contact_page_checked: ok,
  },
}};
```

</details>

### 20 · Save Audit

*Postgres · Main path · Lane 3 · Audit*

**Where it sits.** From: Merge Contact · To: → Score Batch

**Why it exists.** Stores the findings and moves the lead from new to audited.

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryBatching | `transaction` |
| options.queryReplacement | `={{ [ $json.lead_key, $json.site_status, $json.final_url ?? null, $json.https ?? null, $json.mobile_ready ?? null, $json.copyright_year ?? null, $json.has_booking ?? null, $json.booking_provider ?? nu…` |

<details><summary>SQL</summary>

```sql
UPDATE leads_master SET
  site_status      = $2,
  final_url        = $3,
  https            = $4::boolean,
  mobile_ready     = $5::boolean,
  copyright_year   = $6::smallint,
  has_booking      = $7::boolean,
  booking_provider = $8,
  has_contact_form = $9::boolean,
  emails_found     = ARRAY(SELECT jsonb_array_elements_text($10::jsonb)),
  tags             = ARRAY(SELECT DISTINCT unnest(tags || ARRAY(SELECT jsonb_array_elements_text($11::jsonb)))),
  audit_details    = $12::jsonb,
  audited_at       = $13::timestamptz,
  automation_status = 'audited'
WHERE lead_key = $1
  AND automation_status = 'new'
RETURNING lead_key, business_name, site_status, automation_status, tags;
```

</details>

## Lane 4 · Score

*Scores each lead with rules (no AI) through a tested Python service and keeps every score in history.*

### 21 · Score Batch

*Postgres · Main path · Lane 4 · Score*

**Where it sits.** From: Save Audit, Anything to Audit? (false) · To: → Anything to Score?

**Why it exists.** Takes audited leads and counts audited neighbours within 10 km (and how many take bookings or have a working site).

**Settings that matter.** retry: 3 tries, 5000 ms apart · always output data · execute once

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ [ $('Config').first().json.batch_size ] }}` |

<details><summary>SQL</summary>

```sql
WITH batch AS (
  SELECT * FROM leads_master
  WHERE automation_status = 'audited'
  ORDER BY audited_at, id
  LIMIT $1
)
SELECT b.lead_key, b.business_name, b.target_niche, b.country, b.address, b.postcode, b.city,
       b.phone, b.email, b.socials, b.opening_hours, b.osm_last_edit, b.multi_location,
       b.site_status, b.https, b.mobile_ready, b.copyright_year, b.has_booking,
       b.has_contact_form, b.emails_found, b.audit_details, b.tags,
       n.nearby, n.nearby_booking, n.nearby_site
FROM batch b
LEFT JOIN LATERAL (
  SELECT count(*)::int AS nearby,
         (count(*) FILTER (WHERE o.has_booking))::int AS nearby_booking,
         (count(*) FILTER (WHERE o.site_status = 'ok'))::int AS nearby_site
  FROM leads_master o
  WHERE o.lead_key <> b.lead_key
    AND o.automation_status NOT IN ('new', 'excluded')
    AND o.lat IS NOT NULL AND b.lat IS NOT NULL
    AND 6371 * 2 * asin(sqrt(
          power(sin(radians(o.lat - b.lat) / 2), 2) +
          cos(radians(b.lat)) * cos(radians(o.lat)) * power(sin(radians(o.lon - b.lon) / 2), 2)
        )) <= 10
) n ON true;
```

</details>

### 22 · Anything to Score?

*IF · Main path · Lane 4 · Score*

**Where it sits.** From: Score Batch · To: true → Score · false → Review Batch · false → Cold Batch

**Why it exists.** Gate: leads waiting go to scoring; nothing waiting goes straight to cards and the cold summary.

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `strict` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ $json.lead_key }}  string → exists` |
| conditions.combinator | `and` |

### 23 · Score

*HTTP Request · Main path · Lane 4 · Score*

**Where it sits.** From: Anything to Score? (true) · To: → Save Score

**Why it exists.** Sends each lead to the local Python rubric service. Opportunity (up to 70) + Viability (up to 30) = final score, with a tier and the reason for every point.

**Settings that matter.** retry: 3 tries, 5000 ms apart

| Setting | Value |
|---|---|
| method | `POST` |
| url | `http://127.0.0.1:8765/score` |
| sendBody | `True` |
| specifyBody | `json` |
| options.timeout | `5000` |

<details><summary>Request body</summary>

```javascript
{{ JSON.stringify($json) }}
```

</details>

### 24 · Save Score

*Postgres · Main path · Lane 4 · Score*

**Where it sits.** From: Score · To: → Log Score Run

**Why it exists.** Writes the score. A database trigger copies it into score_history, so no score is ever lost to a rescore.

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryBatching | `transaction` |
| options.queryReplacement | `={{ [ $json.lead_key, $json.opportunity_pts, $json.viability_pts, $json.final_score, $json.tier, JSON.stringify($json.tags), JSON.stringify($json.score_reasons), $json.rubric_version, $json.contact_ro…` |

<details><summary>SQL</summary>

```sql
UPDATE leads_master SET
  opportunity_pts   = $2::smallint,
  viability_pts     = $3::smallint,
  final_score       = $4::smallint,
  tier              = $5,
  tags              = ARRAY(SELECT jsonb_array_elements_text($6::jsonb)),
  score_reasons     = $7::jsonb,
  rubric_version    = $8,
  contact_route     = $9,
  email_allowed     = $10::boolean,
  scored_at         = now(),
  automation_status = 'scored'
WHERE lead_key = $1 AND automation_status = 'audited'
RETURNING lead_key, business_name, final_score, tier, tags;
```

</details>

### 25 · Log Score Run

*Postgres · Main path · Lane 4 · Score*

**Where it sits.** From: Save Score · To: → Review Batch · → Cold Batch

**Why it exists.** Records the run in pipeline_events with the rubric version and the leads scored.

**Settings that matter.** execute once

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ JSON.stringify($('Save Score').all().map(i => i.json)) }}, {{ $('Score').first().json.rubric_version }}` |

<details><summary>SQL</summary>

```sql
INSERT INTO pipeline_events (event, rubric_version, leads_affected, lead_keys)
SELECT 'score_run', $2, count(*), array_agg(lead_key)
FROM jsonb_to_recordset($1::jsonb) AS x(lead_key text);
```

</details>

## Lane 5a · Review cards

*Sends a Telegram card for every lead worth a human look, with the buttons that fit it.*

### 26 · Review Batch

*Postgres · Main path · Lane 5a · Review cards*

**Where it sits.** From: Anything to Score? (false), Log Score Run · To: → Build Card

**Why it exists.** Picks scored leads with no card yet (hot, then warm, then holds), plus snoozed leads whose 14 days are up.

**Settings that matter.** retry: 3 tries, 5000 ms apart · execute once

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `=10` |

<details><summary>SQL</summary>

```sql
SELECT lead_key, business_name, target_niche, city, website_url,
       final_score, opportunity_pts, viability_pts, tier, tags,
       score_reasons, rubric_version, contact_route
FROM leads_master
WHERE ((automation_status = 'scored' AND review_sent_at IS NULL)
       OR (automation_status = 'snoozed' AND snooze_until <= now()))
  AND tier IN ('hot', 'warm', 'check_alive', 'needs_check')
ORDER BY CASE tier WHEN 'hot' THEN 1 WHEN 'warm' THEN 2 WHEN 'check_alive' THEN 3 ELSE 4 END,
         final_score DESC
LIMIT $1;
```

</details>

### 27 · Build Card

*Code (JavaScript) · Main path · Lane 5a · Review cards*

**Where it sits.** From: Review Batch · To: → Needs Check?

**Why it exists.** Writes the card: header, score bars, what a customer runs into, signs it is alive, the neighbour gap, links, route and rubric.

| Setting | Value |
|---|---|
| mode | `runOnceForEachItem` |

<details><summary>Code</summary>

```javascript
const L = $input.item.json;
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const bar = (v, max) => { const n = Math.round(((v || 0) / max) * 20); return '#'.repeat(n) + '.'.repeat(20 - n); };
const TIER = { hot: 'HOT', warm: 'WARM', check_alive: 'CHECK ALIVE', needs_check: 'NEEDS CHECK' };
const cap = (s) => (s ? s.split('_').map(w => w[0].toUpperCase() + w.slice(1)).join(' / ') : '');

const reasons = L.score_reasons || [];
const neighbour = reasons.filter(r => r.side === 'opportunity' && /within 10 km/.test(r.label));
const runsInto = reasons.filter(r => r.side === 'opportunity' && !/within 10 km/.test(r.label))
                        .sort((a, b) => b.pts - a.pts);
const alive = reasons.filter(r => r.side === 'viability');

const lines = [];
lines.push(`<b>RECON  |  ${TIER[L.tier]}  ${L.final_score}/100  |  ${esc(cap(L.target_niche))}  |  ${esc(L.city || 'Unknown city')}</b>`);
lines.push(`<b>${esc(L.business_name)}</b>`);
lines.push('');
lines.push(`<pre>Opportunity  ${bar(L.opportunity_pts, 70)}  ${L.opportunity_pts}/70\nViability    ${bar(L.viability_pts, 30)}  ${L.viability_pts}/30</pre>`);

if (L.tier === 'needs_check') lines.push('<i>OpenStreetMap is missing this business\'s details. Check it is open and whether it has a website before acting.</i>');
if (L.tier === 'check_alive') lines.push('<i>Has some details but looks closed. Confirm it is still trading before acting.</i>');

if (runsInto.length) {
  lines.push('', '<b>What a customer runs into</b>');
  runsInto.forEach(r => lines.push(`  x  ${esc(r.label)}  +${r.pts}`));
}
if (alive.length) {
  lines.push('', '<b>Signs it is alive</b>');
  lines.push('  ok  ' + alive.map(r => esc(r.label)).join(', '));
}
if (neighbour.length) {
  lines.push('', '<b>Against its neighbours</b>');
  neighbour.forEach(r => lines.push(`  ${esc(r.label)}  +${r.pts}`));
}

const tags = (L.tags || []).filter(t => t !== 'needs_check');
if (tags.length) lines.push('', 'Tags: ' + tags.join(', '));

const osmPath = L.lead_key.replace(/^osm:/, '');
const search = encodeURIComponent(`${L.business_name} ${L.city || ''} ${L.target_niche || ''}`);
const links = [`<a href="https://www.openstreetmap.org/${osmPath}">Map entry</a>`,
               `<a href="https://www.google.com/search?q=${search}">Search</a>`];
if (L.website_url) links.unshift(`<a href="${esc(L.website_url)}">Website</a>`);
lines.push('', links.join('  |  '));
lines.push(`Route: ${esc(L.contact_route)}  |  Rubric ${esc(L.rubric_version)}  |  ${esc(L.lead_key)}`);

return { json: { lead_key: L.lead_key, tier: L.tier, text: lines.join('\n') } };
```

</details>

### 28 · Needs Check?

*IF · Main path · Lane 5a · Review cards*

**Where it sits.** From: Build Card · To: true → Send Needs-Check Card · false → Send Review Card

**Why it exists.** Chooses the buttons: needs_check leads get Add website / Confirm no site / Closed, the rest get Approve / Reject / Snooze.

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `strict` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ $json.tier }}  string → equals  needs_check` |
| conditions.combinator | `and` |

### 29 · Send Needs-Check Card

*Telegram · Main path · Lane 5a · Review cards*

**Where it sits.** From: Needs Check? (true) · To: → Mark Sent

**Why it exists.** Sends a hold card for a lead whose map entry is missing details.

| Setting | Value |
|---|---|
| chatId | `={{ $('Config').first().json.review_chat_id }}` |
| text | `={{ $json.text }}` |
| replyMarkup | `inlineKeyboard` |
| inlineKeyboard.rows[0].row.buttons[0].text | `Add website` |
| inlineKeyboard.rows[0].row.buttons[0].additionalFields.callback_data | `=aw\|{{ $json.lead_key }}` |
| inlineKeyboard.rows[0].row.buttons[1].text | `Confirm no site` |
| inlineKeyboard.rows[0].row.buttons[1].additionalFields.callback_data | `=ns\|{{ $json.lead_key }}` |
| inlineKeyboard.rows[0].row.buttons[2].text | `Closed` |
| inlineKeyboard.rows[0].row.buttons[2].additionalFields.callback_data | `=cl\|{{ $json.lead_key }}` |
| additionalFields.appendAttribution | `False` |
| additionalFields.disable_web_page_preview | `True` |
| additionalFields.parse_mode | `HTML` |

### 30 · Send Review Card

*Telegram · Main path · Lane 5a · Review cards*

**Where it sits.** From: Needs Check? (false) · To: → Mark Sent

**Why it exists.** Sends a decision card.

| Setting | Value |
|---|---|
| chatId | `={{ $('Config').first().json.review_chat_id }}` |
| text | `={{ $json.text }}` |
| replyMarkup | `inlineKeyboard` |
| inlineKeyboard.rows[0].row.buttons[0].text | `=Approve` |
| inlineKeyboard.rows[0].row.buttons[0].additionalFields.callback_data | `=ap\|{{ $json.lead_key }}` |
| inlineKeyboard.rows[0].row.buttons[1].text | `Reject` |
| inlineKeyboard.rows[0].row.buttons[1].additionalFields.callback_data | `=rj\|{{ $json.lead_key }}` |
| inlineKeyboard.rows[0].row.buttons[2].text | `Snooze 14d` |
| inlineKeyboard.rows[0].row.buttons[2].additionalFields.callback_data | `=sz\|{{ $json.lead_key }}` |
| additionalFields.appendAttribution | `False` |
| additionalFields.disable_web_page_preview | `True` |
| additionalFields.parse_mode | `HTML` |

### 31 · Mark Sent

*Postgres · Main path · Lane 5a · Review cards*

**Where it sits.** From: Send Needs-Check Card, Send Review Card · To: (end of branch)

**Why it exists.** Saves the card's chat and message ID (so it can be edited later) and moves the lead to in_review.

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ $('Build Card').item.json.lead_key }}, {{ $json.result.chat.id }}, {{ $json.result.message_id }}` |

<details><summary>SQL</summary>

```sql
UPDATE leads_master SET
  review_sent_at    = now(),
  review_chat_id    = $2,
  review_message_id = $3,
  automation_status = 'in_review'
WHERE lead_key = $1 AND automation_status IN ('scored', 'snoozed')
RETURNING lead_key, business_name, tier;
```

</details>

## Lane Cold summary

*Lists leads that are doing fine in one daily message instead of one card each.*

### 32 · Cold Batch

*Postgres · Main path · Lane Cold summary*

**Where it sits.** From: Anything to Score? (false), Log Score Run · To: → Build Summary

**Why it exists.** Collects cold leads that have not been listed yet.

**Settings that matter.** retry: 3 tries, 5000 ms apart · execute once

| Setting | Value |
|---|---|
| operation | `executeQuery` |

<details><summary>SQL</summary>

```sql
SELECT lead_key, business_name, target_niche, final_score, tags
FROM leads_master
WHERE automation_status = 'scored' AND tier = 'cold' AND summarized_at IS NULL
ORDER BY final_score DESC;
```

</details>

### 33 · Build Summary

*Code (JavaScript) · Main path · Lane Cold summary*

**Where it sits.** From: Cold Batch · To: → Send Summary

**Why it exists.** Groups locations of the same brand into one line and writes the summary.

<details><summary>Code</summary>

```javascript
const rows = $input.all().map(i => i.json);
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const niche = (s) => (s || '').split('_').join(' / ');

// group locations of the same brand into one line
const groups = new Map();
rows.forEach(r => {
  const k = (r.business_name || '').toLowerCase();
  if (!groups.has(k)) groups.set(k, { name: r.business_name, niche: r.target_niche, scores: [], growth: false });
  const g = groups.get(k);
  g.scores.push(r.final_score);
  if ((r.tags || []).includes('growth_prospect')) g.growth = true;
});

const list = [...groups.values()].sort((a, b) => Math.max(...b.scores) - Math.max(...a.scores));
const shown = list.slice(0, 40);

const lines = [
  `<b>RECON  |  Cold summary  |  ${rows.length} lead${rows.length === 1 ? '' : 's'}</b>`,
  '<i>Doing fine for now, so no card each. Logged for later.</i>',
  '',
];
shown.forEach(g => {
  const hi = Math.max(...g.scores), lo = Math.min(...g.scores);
  const score = g.scores.length > 1 ? `${hi}` : `${hi}`;
  const count = g.scores.length > 1 ? `  x${g.scores.length} (${lo}–${hi})` : '';
  const growth = g.growth ? '  (growth prospect)' : '';
  lines.push(`${score}  ${esc(g.name)}${count}  |  ${esc(niche(g.niche))}${growth}`);
});
if (list.length > shown.length) lines.push('', `...and ${list.length - shown.length} more`);

return [{ json: { text: lines.join('\n'), lead_keys: rows.map(r => r.lead_key) } }];
```

</details>

### 34 · Send Summary

*Telegram · Main path · Lane Cold summary*

**Where it sits.** From: Build Summary · To: → Mark Summarized

**Why it exists.** Sends the cold summary to Telegram.

| Setting | Value |
|---|---|
| chatId | `={{ $('Config').first().json.review_chat_id }}` |
| text | `={{ $json.text }}` |
| additionalFields.appendAttribution | `False` |
| additionalFields.parse_mode | `HTML` |

### 35 · Mark Summarized

*Postgres · Main path · Lane Cold summary*

**Where it sits.** From: Send Summary · To: (end of branch)

**Why it exists.** Stamps each listed lead so it never appears in a summary twice.

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ JSON.stringify($('Build Summary').first().json.lead_keys) }}` |

<details><summary>SQL</summary>

```sql
UPDATE leads_master SET summarized_at = now()
WHERE lead_key IN (SELECT jsonb_array_elements_text($1::jsonb))
RETURNING lead_key;
```

</details>

---

## Poll Taps path

## Lane 5b · Read taps

*Every minute, asks Telegram whether you tapped anything, and reads each tap exactly once.*

### 36 · Poll Taps

*Schedule Trigger · Poll Taps path · Lane 5b · Read taps*

**Where it sits.** From: (trigger, starts the path) · To: → Get Offset

**Why it exists.** Starts the decision path every minute. No webhook and no tunnel needed.

| Setting | Value |
|---|---|
| rule.interval[0].field | `minutes` |
| rule.interval[0].minutesInterval | `1` |

### 37 · Get Offset

*Postgres · Poll Taps path · Lane 5b · Read taps*

**Where it sits.** From: Poll Taps · To: → Get Updates

**Why it exists.** Reads the last Telegram update already handled.

**Settings that matter.** retry: 3 tries, 5000 ms apart

| Setting | Value |
|---|---|
| operation | `executeQuery` |

<details><summary>SQL</summary>

```sql
SELECT last_update_id FROM telegram_poll_state WHERE bot = 'recon';
```

</details>

### 38 · Get Updates

*HTTP Request · Poll Taps path · Lane 5b · Read taps*

**Where it sits.** From: Get Offset · To: → Any Updates?

**Why it exists.** Asks Telegram for anything newer than that. Retries 3 times on a network blip.

**Settings that matter.** retry: 3 tries, 5000 ms apart

| Setting | Value |
|---|---|
| url | `=https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/getUpdates` |
| sendQuery | `True` |
| queryParameters.parameters › offset | `={{ Number($json.last_update_id) + 1 }}` |
| queryParameters.parameters › timeout | `0` |
| queryParameters.parameters › allowed_updates | `=[]` |

### 39 · Any Updates?

*IF · Poll Taps path · Lane 5b · Read taps*

**Where it sits.** From: Get Updates · To: true → Save Offset

**Why it exists.** Ends quietly when there is nothing new.

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `strict` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ $json.result.length }}  number → gt  0` |
| conditions.combinator | `and` |

### 40 · Save Offset

*Postgres · Poll Taps path · Lane 5b · Read taps*

**Where it sits.** From: Any Updates? (true) · To: → One per Update

**Why it exists.** Marks the updates as read before processing, so a tap is never handled twice.

**Settings that matter.** execute once

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ Math.max(...$json.result.map(u => u.update_id)) }}` |

<details><summary>SQL</summary>

```sql
UPDATE telegram_poll_state
SET last_update_id = $1, polled_at = now()
WHERE bot = 'recon' AND last_update_id < $1;
```

</details>

### 41 · One per Update

*Code (JavaScript) · Poll Taps path · Lane 5b · Read taps*

**Where it sits.** From: Save Offset · To: → Parse Tap

**Why it exists.** Splits the updates into one item each.

<details><summary>Code</summary>

```javascript
return $('Get Updates').first().json.result.map(u => ({ json: u }));
```

</details>

### 42 · Parse Tap

*Code (JavaScript) · Poll Taps path · Lane 5b · Read taps*

**Where it sits.** From: One per Update · To: → Route

**Why it exists.** Turns each update into a kind (tap, website_reply, ignore), an action, a lead and the card it came from.

| Setting | Value |
|---|---|
| mode | `runOnceForEachItem` |

<details><summary>Code</summary>

```javascript
const u = $input.item.json;
const ACTIONS = { ap: 'approve', rj: 'reject', sz: 'snooze', aw: 'add_website', ns: 'confirm_no_site', cl: 'closed' };
const who = (f) => f?.username || f?.first_name || String(f?.id || 'unknown');

if (u.callback_query) {
  const q = u.callback_query;
  const [code, ...rest] = (q.data || '').split('|');
  return { json: {
    update_id: u.update_id,
    kind: ACTIONS[code] ? 'tap' : 'ignore',
    action: ACTIONS[code] || null,
    lead_key: rest.join('|'),
    callback_id: q.id,
    chat_id: q.message?.chat?.id,
    message_id: q.message?.message_id,
    decided_by: who(q.from),
  }};
}

const m = u.message;
const ref = m?.reply_to_message?.text || '';
const hit = ref.match(/lead:\s*(osm:\S+)/);
if (m && hit) {
  return { json: {
    update_id: u.update_id, kind: 'website_reply', action: 'add_website',
    lead_key: hit[1], url: (m.text || '').trim(),
    chat_id: m.chat.id, message_id: m.message_id, decided_by: who(m.from),
  }};
}

return { json: { update_id: u.update_id, kind: 'ignore' } };
```

</details>

### 43 · Route

*Switch · Poll Taps path · Lane 5b · Read taps*

**Where it sits.** From: Parse Tap · To: tap → Is Add Website? · website_reply → Save Website

**Why it exists.** Button taps go one way, URL replies the other, anything else stops.

| Setting | Value |
|---|---|
| rules.values[0].conditions.options.caseSensitive | `True` |
| rules.values[0].conditions.options.typeValidation | `strict` |
| rules.values[0].conditions.options.version | `3` |
| rules.values[0].conditions.conditions | `={{ $json.kind }}  string → equals  tap` |
| rules.values[0].conditions.combinator | `and` |
| rules.values[0].renameOutput | `True` |
| rules.values[0].outputKey | `tap` |
| rules.values[1].conditions.options.caseSensitive | `True` |
| rules.values[1].conditions.options.typeValidation | `strict` |
| rules.values[1].conditions.options.version | `3` |
| rules.values[1].conditions.conditions | `={{ $json.kind }}  string → equals  website_reply` |
| rules.values[1].conditions.combinator | `and` |
| rules.values[1].renameOutput | `True` |
| rules.values[1].outputKey | `website_reply` |

## Lane Button taps

*Turns a tap into a decision that is written once, logged forever, and shown on the card.*

### 44 · Is Add Website?

*IF · Poll Taps path · Lane Button taps*

**Where it sits.** From: Route (tap) · To: true → Ask for URL · false → Write Decision

**Why it exists.** The Add website button starts a two-step conversation; every other button is a decision.

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `strict` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ $json.action }}  string → equals  add_website` |
| conditions.combinator | `and` |

### 45 · Ask for URL

*Telegram · Poll Taps path · Lane Button taps*

**Where it sits.** From: Is Add Website? (true) · To: → Answer Add Website

**Why it exists.** Asks you to reply with the website address (the lead is named in the message so your reply can be matched).

| Setting | Value |
|---|---|
| chatId | `={{ $json.chat_id }}` |
| text | `=Reply to this message with the website address. lead: {{ $json.lead_key }}` |
| replyMarkup | `forceReply` |
| forceReply.force_reply | `True` |
| additionalFields.appendAttribution | `False` |

### 46 · Answer Add Website

*Telegram · Poll Taps path · Lane Button taps*

**Where it sits.** From: Ask for URL · To: (end of branch)

**Why it exists.** Stops the button spinner. Continues on error: a late answer changes nothing.

**Settings that matter.** on error: continue

| Setting | Value |
|---|---|
| resource | `callback` |
| queryId | `={{ $('Is Add Website?').item.json.callback_id }}` |
| additionalFields.text | `Send the URL as a reply` |

### 47 · Write Decision

*Postgres · Poll Taps path · Lane Button taps*

**Where it sits.** From: Is Add Website? (false) · To: → Decided?

**Why it exists.** Acts only if the lead is still in_review, the action is allowed, and the tap came from the card's chat. Updates the lead and appends to lead_decisions in one step, and always returns one row saying whether it decided.

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ $json.lead_key }}, {{ $json.action }}, {{ $json.chat_id }}, {{ $json.decided_by }}, {{ $json.callback_id }}, {{ $json.message_id }}` |

<details><summary>SQL</summary>

```sql
WITH lead AS (
  SELECT lead_key, final_score, tier, score_reasons, rubric_version
  FROM leads_master
  WHERE lead_key = $1
    AND automation_status = 'in_review'
    AND review_chat_id = $3::bigint
    AND $2::text IN ('approve', 'reject', 'snooze', 'closed', 'confirm_no_site')
  FOR UPDATE
),
upd AS (
  UPDATE leads_master m SET
    automation_status = CASE $2::text
      WHEN 'approve'         THEN 'approved'::lead_state
      WHEN 'reject'          THEN 'rejected'::lead_state
      WHEN 'snooze'          THEN 'snoozed'::lead_state
      WHEN 'closed'          THEN 'excluded'::lead_state
      WHEN 'confirm_no_site' THEN 'audited'::lead_state
    END,
    snooze_until   = CASE WHEN $2::text = 'snooze' THEN now() + interval '14 days' ELSE m.snooze_until END,
    tags = CASE $2::text
      WHEN 'closed'          THEN array_append(m.tags, 'closed_confirmed')
      WHEN 'confirm_no_site' THEN array_append(array_remove(m.tags, 'needs_check'), 'no_site_confirmed')
      ELSE m.tags
    END,
    review_sent_at = CASE WHEN $2::text IN ('snooze', 'confirm_no_site') THEN NULL ELSE m.review_sent_at END
  FROM lead
  WHERE m.lead_key = lead.lead_key
  RETURNING m.lead_key, m.business_name, m.automation_status::text AS new_status
),
dec AS (
  INSERT INTO lead_decisions (lead_key, decision, final_score, tier, score_reasons, rubric_version, decided_via, decided_by)
  SELECT lead_key, $2::text, final_score, tier, score_reasons, rubric_version, 'telegram', $4::text
  FROM lead
  RETURNING id
)
SELECT $1::text AS lead_key, $2::text AS action,
       u.business_name, u.new_status,
       (u.lead_key IS NOT NULL) AS decided,
       (SELECT id FROM dec) AS decision_id,
       $3::bigint AS chat_id, $5::text AS callback_id, $6::bigint AS message_id
FROM (SELECT 1) AS one
LEFT JOIN upd u ON true;
```

</details>

### 48 · Decided?

*IF · Poll Taps path · Lane Button taps*

**Where it sits.** From: Write Decision · To: true → Edit Card · false → Answer Stale

**Why it exists.** Real decisions update the card; stale or duplicate taps get a polite "already decided".

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `strict` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ $json.decided }}  boolean → true` |
| conditions.combinator | `and` |

### 49 · Edit Card

*HTTP Request · Poll Taps path · Lane Button taps*

**Where it sits.** From: Decided? (true) · To: → Answer Tap

**Why it exists.** Replaces the card's buttons with one label, e.g. "Rejected · Oct 16, 6:50 pm".

| Setting | Value |
|---|---|
| method | `POST` |
| url | `=https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/editMessageReplyMarkup` |
| sendBody | `True` |
| specifyBody | `json` |

<details><summary>Request body</summary>

```javascript
{{ JSON.stringify({
  chat_id: $json.chat_id,
  message_id: $json.message_id,
  reply_markup: { inline_keyboard: [[{
    text: ({ approve: 'Approved', reject: 'Rejected', snooze: 'Snoozed 14 days', closed: 'Marked closed', confirm_no_site: 'No site confirmed, rescoring' })[$json.action]
          + ' · ' + $now.setZone('America/Chicago').toFormat('MMM d, h:mm a'),
    callback_data: 'done'
  }]] }
}) }}
```

</details>

### 50 · Answer Tap

*Telegram · Poll Taps path · Lane Button taps*

**Where it sits.** From: Edit Card · To: (end of branch)

**Why it exists.** Shows "Saved" and stops the spinner. Continues on error.

**Settings that matter.** on error: continue

| Setting | Value |
|---|---|
| resource | `callback` |
| queryId | `={{ $('Write Decision').item.json.callback_id }}` |
| additionalFields.text | `Saved` |

### 51 · Answer Stale

*Telegram · Poll Taps path · Lane Button taps*

**Where it sits.** From: Decided? (false) · To: (end of branch)

**Why it exists.** Shows "Already decided, nothing changed". Continues on error.

**Settings that matter.** on error: continue

| Setting | Value |
|---|---|
| resource | `callback` |
| queryId | `={{ $json.callback_id }}` |
| additionalFields.text | `Already decided, nothing changed` |

## Lane URL replies

*Step two of Add website: saves the address you replied with and sends the lead back to the audit.*

### 52 · Save Website

*Postgres · Poll Taps path · Lane URL replies*

**Where it sits.** From: Route (website_reply) · To: → Website Saved?

**Why it exists.** Checks the reply is a web address, saves it as a manual website, copies it to same-name locations within 50 km, logs a decision for each, and sends them back to the audit.

| Setting | Value |
|---|---|
| operation | `executeQuery` |
| options.queryReplacement | `={{ $json.lead_key }}, {{ /^https?:\/\//i.test($json.url) ? $json.url : 'https://' + $json.url }}, {{ $json.chat_id }}, {{ $json.decided_by }}` |

<details><summary>SQL</summary>

```sql
WITH lead AS (
  SELECT lead_key, business_name, lat, lon, final_score, tier, score_reasons, rubric_version
  FROM leads_master
  WHERE lead_key = $1
    AND automation_status = 'in_review'
    AND review_chat_id = $3::bigint
    AND $2::text ~* '^https?://[^\s/]+\.[^\s]+'
  FOR UPDATE
),
upd AS (
  UPDATE leads_master m SET
    website_url       = $2::text,
    website_domain    = regexp_replace(lower($2::text), '^https?://(www\.)?([^/:]+).*$', '\2'),
    website_source    = 'manual',
    automation_status = 'new',
    tags              = array_remove(m.tags, 'needs_check'),
    review_sent_at    = NULL
  FROM lead
  WHERE m.lead_key = lead.lead_key
  RETURNING m.lead_key, m.business_name, m.review_message_id
),
sib AS (
  UPDATE leads_master s SET
    website_url       = $2::text,
    website_domain    = regexp_replace(lower($2::text), '^https?://(www\.)?([^/:]+).*$', '\2'),
    website_source    = 'manual',
    automation_status = 'new',
    tags              = array_remove(s.tags, 'needs_check'),
    review_sent_at    = NULL
  FROM lead l
  WHERE s.lead_key <> l.lead_key
    AND lower(s.business_name) = lower(l.business_name)
    AND s.website_url IS NULL
    AND s.automation_status IN ('new', 'audited', 'scored', 'in_review')
    AND s.lat IS NOT NULL AND l.lat IS NOT NULL
    AND 6371 * 2 * asin(sqrt(
          power(sin(radians(s.lat - l.lat) / 2), 2) +
          cos(radians(l.lat)) * cos(radians(s.lat)) * power(sin(radians(s.lon - l.lon) / 2), 2)
        )) <= 50
  RETURNING s.lead_key, s.final_score, s.tier, s.score_reasons, s.rubric_version
),
dec AS (
  INSERT INTO lead_decisions (lead_key, decision, final_score, tier, score_reasons, rubric_version, note, decided_via, decided_by)
  SELECT lead_key, 'add_website', final_score, tier, score_reasons, rubric_version,
         'Website added: ' || $2::text, 'telegram', $4::text
  FROM lead
  UNION ALL
  SELECT lead_key, 'add_website', final_score, tier, score_reasons, rubric_version,
         'Website copied from ' || $1::text || ': ' || $2::text, 'telegram', $4::text
  FROM sib
  RETURNING id
)
SELECT $1::text AS lead_key, $2::text AS url, u.business_name,
       (u.lead_key IS NOT NULL) AS saved,
       u.review_message_id, $3::bigint AS chat_id,
       (SELECT count(*) FROM sib) AS siblings_updated
FROM (SELECT 1) AS one
LEFT JOIN upd u ON true;
```

</details>

### 53 · Website Saved?

*IF · Poll Taps path · Lane URL replies*

**Where it sits.** From: Save Website · To: true → Edit Old Card · false → Reply Invalid

**Why it exists.** Saved goes to the confirmation; anything else to the "that didn't save" reply.

| Setting | Value |
|---|---|
| conditions.options.caseSensitive | `True` |
| conditions.options.typeValidation | `strict` |
| conditions.options.version | `3` |
| conditions.conditions | `={{ $json.saved }}  boolean → true` |
| conditions.combinator | `and` |

### 54 · Edit Old Card

*HTTP Request · Poll Taps path · Lane URL replies*

**Where it sits.** From: Website Saved? (true) · To: → Confirm Website

**Why it exists.** Closes the old card with "Website added, re-auditing".

| Setting | Value |
|---|---|
| method | `POST` |
| url | `=https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/editMessageReplyMarkup` |
| sendBody | `True` |
| specifyBody | `json` |

<details><summary>Request body</summary>

```javascript
{{ JSON.stringify({
  chat_id: $json.chat_id,
  message_id: $json.review_message_id,
  reply_markup: { inline_keyboard: [[{
    text: 'Website added, re-auditing · ' + $now.setZone('America/Chicago').toFormat('MMM d, h:mm a'),
    callback_data: 'done'
  }]] }
}) }}
```

</details>

### 55 · Confirm Website

*Telegram · Poll Taps path · Lane URL replies*

**Where it sits.** From: Edit Old Card · To: (end of branch)

**Why it exists.** Tells you the lead (and any sister locations) goes back through the audit on the next run.

| Setting | Value |
|---|---|
| chatId | `={{ $('Save Website').item.json.chat_id }}` |
| text | `=Got it: {{ $('Save Website').item.json.business_name }} goes back through the audit on the next run{{ $('Save Website').item.json.siblings_updated > 0 ? ', plus ' + $('Save Website').item.json.siblin…` |
| additionalFields.appendAttribution | `False` |

### 56 · Reply Invalid

*Telegram · Poll Taps path · Lane URL replies*

**Where it sits.** From: Website Saved? (false) · To: (end of branch)

**Why it exists.** Explains what to fix: a full web address, on a card still waiting for a decision.

| Setting | Value |
|---|---|
| chatId | `={{ $json.chat_id }}` |
| text | `=That didn't save. Send a full web address (like https://example.com), and check the card is still waiting for a decision.` |
| additionalFields.appendAttribution | `False` |

---

## Error lane

## Lane Error lane

*Tells you within a minute when any published run fails, and where.*

### 57 · Error Trigger

*Error Trigger · Error lane · Lane Error lane*

**Where it sits.** From: (trigger, starts the path) · To: → Error Alert

**Why it exists.** Fires when any published run of this workflow fails (Workflow Settings → Error Workflow points here).

### 58 · Error Alert

*Telegram · Error lane · Lane Error lane*

**Where it sits.** From: Error Trigger · To: (end of branch)

**Why it exists.** Sends the failed node, the reason and a link to the run.

| Setting | Value |
|---|---|
| chatId | `YOUR_TELEGRAM_CHAT_ID` |
| text | `=<b>RECON error</b> Node: {{ $json.execution.lastNodeExecuted }} What happened: {{ String($json.execution.error.message \|\| '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') }} R…` |
| additionalFields.appendAttribution | `False` |
| additionalFields.parse_mode | `HTML` |

---

## Database migrations

Run in order in the Neon SQL Editor. Each file explains why it exists at the top.

| File | Adds |
|---|---|
| `01_vault_schema.sql` | the base tables: leads_master, email_log, reply_labels, suppression_list, review_queue |
| `03_v1_audit_score_trail.sql` | audit and score columns, lead states, lead_decisions (append-only), mining_runs |
| `04_score_history_events.sql` | score_history and pipeline_events (append-only), reset_scores() |
| `05_review_gate.sql` | card columns (sent time, chat, message id) and the Telegram polling offset |
| `06_manual_website.sql` | website_source, so hand-added websites survive re-mining |
| `07_cold_summary.sql` | summarized_at, so each cold lead is listed once |
| `08_reset_guard.sql` | reset_scores() respects only final decisions |
