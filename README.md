# PulseGraph AI

**Social Intelligence. Explained.**
_See what changed. Understand why. Trace how it spread._

An AI-driven social media analytics framework that turns raw multi-platform
conversation into audience intelligence: what people are saying, how they feel,
who is participating, which topics are rising, and how information and influence
move through the network.

It runs entirely offline on a deterministic demo dataset — **no API keys, no paid
services, no infrastructure beyond SQLite.**

---

## Table of contents

- [Problem statement](#problem-statement)
- [What makes this different](#what-makes-this-different)
- [Architecture](#architecture)
- [Quick start](#quick-start)
- [Demo walkthrough](#demo-walkthrough)
- [Features](#features)
- [Technology stack](#technology-stack)
- [Configuring AI](#configuring-ai)
- [Connecting real social APIs](#connecting-real-social-apis)
- [API reference](#api-reference)
- [Database model](#database-model)
- [Testing](#testing)
- [Privacy and ethics](#privacy-and-ethics)
- [Design decisions](#design-decisions)
- [Future improvements](#future-improvements)

---

## Problem statement

> Social media platforms are complex ecosystems driven by human emotion, diverse
> demographics, and interconnected networks. Understanding an online community
> requires understanding how followers feel (**sentiment**), who they are
> (**demographics**), what captivates them (**trends**), and how they influence
> one another (**link analysis**).

The system must deliver five components:

| # | Requirement | Where it lives |
|---|---|---|
| **A** | Continuous data collection & timeline management | `backend/app/ingestion/` |
| **B** | Multi-dimensional sentiment inference (incl. sarcasm) | `backend/app/ai/local_provider.py` |
| **C** | Automated demographic profiling | `backend/app/analytics/demographics.py` |
| **D** | Real-time trend & topic detection | `backend/app/analytics/trends.py`, `topics.py` |
| **E** | Link analysis & network topology | `backend/app/analytics/network.py` |

Platform coverage: **X and Telegram** (essential), **Instagram and Facebook**
(desirable), **Reddit and YouTube** (appreciable) — all six have adapters.

---

## What makes this different

A generic dashboard shows you that a number moved. PulseGraph correlates the
dimensions and tells you *what changed, who drove it, how it spread, and why it
thinks so* — with the arithmetic attached.

### 1. Audience Pulse
The central intelligence statement. It fuses sentiment, topic momentum, audience
segments, engagement and network influence into one paragraph:

> *NovaPhone X battery drain is viral: 545 mentions in the last 12 hours versus
> 11 in the 12 before (+4855%), trend score 87/100. Likely driver: volume growth
> +4855%; engagement velocity 1,719 interactions/hour. Observed across facebook,
> reddit, telegram, x. The change is most pronounced in Highly Engaged
> Supporters. Telegram activity preceded the increase elsewhere by about 54
> minutes.*

Every figure in that sentence is a computed metric, listed under **Why?**.

### 2. AI Intelligence Feed
Typed detections — not notifications. Ten independent detectors produce cards
carrying severity, confidence band, time window, affected segments, involved
accounts, platforms, an evidence table and a recommended interpretation.

### 3. Narrative Journey
Reconstructs how a topic actually evolved, discovered from the data rather than
scripted: episode onset → cross-platform arrival with lead time → sentiment
inflection → high-influence participation → volume breakout → second audience
segment entering → peak.

### 4. Cross-platform sentiment divergence
The same narrative behaves differently by community. The platform breakdown
quantifies the spread between the most positive and most negative platform.

### 5. Influence flow & bridge detection
PageRank, betweenness and greedy-modularity communities over the real
interaction graph. Bridge accounts are identified by cross-community edge ratio
*and* top-decile betweenness — not merely by popularity.

### 6. Evidence-backed explanation
Every AI-attributed conclusion has a **Why?** control that expands into the
metrics that triggered it, with the value, change and period for each.

---

## Architecture

```
                    ┌──────────────────────────────────────┐
                    │      DataSourceAdapter (ABC)         │
                    │  X · Telegram · Instagram · Facebook │
                    │  Reddit · YouTube · DemoDataAdapter  │
                    └──────────────┬───────────────────────┘
                                   │  NormalizedPost / NormalizedAuthor
                                   ▼
   INGEST → NORMALIZE → STORE → SENTIMENT → TOPIC EXTRACTION → ENRICH (graph)
      → NETWORK ANALYSIS → DEMOGRAPHIC AGGREGATION → SEGMENTATION
      → TREND ANALYSIS → INTELLIGENCE GENERATION → DASHBOARD
                                   │
                    ┌──────────────┴───────────────┐
                    │   SQLite (PostgreSQL-ready)  │
                    └──────────────┬───────────────┘
                                   ▼
                      AnalyticsService (read side)
                    one filter object → every view
                                   ▼
                    FastAPI  /api/*  →  Next.js dashboard
```

The pipeline is one class (`analytics/pipeline.py`) with one method per stage,
each logging what it produced into `analysis_runs.stage_log`. Deliberately a
modular monolith: no queue, no scheduler, no microservices.

### Where AI is and is not used

This distinction is enforced in code:

| Task | Method | Rationale |
|---|---|---|
| Sentiment, emotion, stance, sarcasm | **NLP engine** | Genuine language understanding |
| Topic assignment | Weighted keyword + ITF + thread context | Deterministic, inspectable |
| Trend score, velocity, momentum | Time-series statistics | Arithmetic is not AI |
| Demographic inference | Rule-based over public signals | Auditable, confidence-bounded |
| Segmentation | Weighted prototype nearest-neighbour | Membership must be defensible |
| Network metrics | NetworkX | Established graph algorithms |
| Narrative phrasing | **AI provider** | Phrases already-computed numbers |

`AIProvider.interpret()` receives a brief of computed figures and returns a
sentence. It never produces a number, and its output is parsed into typed
structures — free text never reaches application logic.

### Repository layout

```
PulseGraph-AI/
├── backend/
│   ├── app/
│   │   ├── main.py              FastAPI app, error handlers
│   │   ├── config.py            Settings (everything optional)
│   │   ├── db.py                Engine / session
│   │   ├── models.py            12 SQLAlchemy models
│   │   ├── schemas.py           Pydantic API contracts
│   │   ├── api/                 Routes + filter dependencies
│   │   ├── ingestion/           Adapter interface, 6 platforms, demo generator
│   │   ├── ai/                  Provider ABC, local NLP engine, OpenAI provider
│   │   └── analytics/           topics · sentiment · demographics · segments
│   │                            network · trends · journey · intelligence
│   │                            filters · queries · pipeline
│   └── tests/                   171 tests
├── frontend/
│   ├── app/                     Routes: / dashboard topics audience network
│   │                            timeline data privacy
│   ├── components/              ui · layout · charts · network
│   ├── features/                filters · pulse · intelligence · journey
│   │                            audience · trends
│   ├── lib/                     api client · formatting · colour tokens
│   ├── hooks/                   useApi
│   └── types/                   Typed mirror of the API contracts
├── docs/
└── data/                        SQLite database (gitignored)
```

---

## Quick start

**Prerequisites:** Python 3.11+ and Node.js 18+.

**One command**, from the project folder:

```powershell
.\start.ps1
```

```bash
./start.sh
```

It creates the virtual environment, installs both dependency sets, generates the
demo dataset, runs the pipeline and starts both services. First run takes 3–5
minutes; after that use `-SkipSetup` / `--skip-setup`.

New to the project? See **[SETUP.md](SETUP.md)** for prerequisites,
troubleshooting and what to look at first.

### Manual steps

### 1. Backend

```bash
cd backend
python -m venv .venv
```

```bash
.venv\Scripts\activate
```

```bash
pip install -r requirements.txt
```

```bash
uvicorn app.main:app --reload --port 8000
```

On macOS/Linux the activate step is `source .venv/bin/activate`.

### 2. Load the demo dataset

```bash
curl -X POST http://127.0.0.1:8000/api/ingestion/demo -H "Content-Type: application/json" -d "{}"
```

Or click **Load Demo Intelligence** on the `/data` page once the UI is running.

### 3. Frontend

```bash
cd frontend
npm install
```

```bash
copy .env.local.example .env.local
```

```bash
npm run dev
```

Open **http://localhost:3000**. No `.env` file is required for either service.

---

## Demo walkthrough

The demo dataset simulates a realistic product incident. **Nothing about this
story is hard-coded into the analytics** — the engine rediscovers it from post
text and interaction structure.

> A niche Telegram channel starts reporting battery drain after the fictional
> NovaPhone X v14.2 update. Technical reviewers corroborate it. The complaint
> crosses to X about an hour later, accelerates, pulls in a second and less
> technical audience, spawns a recall rumour that gets partially debunked, and
> drives a wave of support complaints.

A 3–5 minute walkthrough:

| Step | Action | What to point at |
|---|---|---|
| 1 | Open `/dashboard` | **Audience Pulse** — the whole situation in one paragraph |
| 2 | Click **Why?** on the Pulse | The evidence table: mentions, growth, velocity, lead time |
| 3 | Look at the KPI strip | Every value carries its change vs the previous window |
| 4 | Open the top **Trend Radar** row → *How was this scored?* | The 7-component formula, not a magic number |
| 5 | Click the topic → `/topics/battery-drain` | **Narrative Journey**: Telegram origin → reviewer → X at +51 min → sentiment turns → Reddit → Facebook → peak |
| 6 | Scroll to **Cross-platform divergence** | The same topic reads differently per community |
| 7 | Open `/network` | Node size = influence, colour = segment, ring = bridge account |
| 8 | Open `/audience` and compare two segments | Which audience moved, and by how much |
| 9 | Open `/data` → **Live NLP probe** | Paste *"Great, another three-hour outage. Amazing service."* → literal **positive**, contextual **negative**, sarcasm **likely** |
| 10 | Apply a platform filter | Every panel — including the Pulse — re-derives from the filtered rows |

Closing line: *the system does not just say something is trending; it explains
who is driving it, where it started, how it is spreading, which audience is
reacting, and what changed.*

### Detectable events in the demo data

All ten are produced by independent detectors: sentiment spike · emerging topic ·
trend acceleration · cross-platform spread · influencer amplification · audience
segment shift · cross-platform sentiment divergence · bridge node discovery ·
narrative journey · declining trend.

---

## Features

### Data collection & timeline
- Six platform adapters plus a demo adapter behind one `DataSourceAdapter` interface
- Single normalised schema: id, platform, author, text, timestamp, language,
  reply/parent ids, hashtags, mentions, likes, comments, shares, views, location
- Chronological event timeline with hourly / 6-hourly / daily / weekly aggregation
- Filtering by date range, platform, topic, sentiment, emotion, audience segment

### Sentiment engine
- **Sentiment**: positive · negative · neutral
- **Stance**: supportive · against · neutral
- **Emotion**: excited · satisfied · curious · confused · concerned · anxious ·
  frustrated · angry · sarcastic · neutral
- Negation, intensifiers, diminishers, multi-word idioms, conservative stemming
- **Hinglish/romanised-Hindi lexicon** — code-switched posts score zero under a
  generic English lexicon
- Every result stores model, version, confidence, timestamp, status and the
  matched cues

### Sarcasm handling
Sarcasm is treated as a *conflict* between surface praise and contextual
meaning, not a keyword lookup. Signals: praise openers, ironic constructions,
positive wording around failure context, and a positive literal reading of a
described failure. The UI shows literal sentiment, contextual sentiment, sarcasm
likelihood, and the final interpretation — and confidence is capped on a
reversed reading, because inverting is inherently less certain.

### Demographics
Age bracket, region, language, professional interest and engagement behaviour,
each with a confidence band and the public signal that produced it. Age
inference is capped below the High band by design. Attributes with no supporting
signal resolve to `unknown` rather than being guessed.

### Audience segmentation
Six behavioural segments derived from a five-dimensional feature vector (reach,
activity, negativity, amplification, technical register) via weighted prototype
matching, so membership is always explainable.

### Trends
Seven-component composite score normalised 0–100 → stable / emerging / growing /
accelerating / viral, plus velocity, acceleration, and a **momentum forecast**
(exponential smoothing + recent slope) labelled as an estimate with confidence.

### Network
Degree centrality, betweenness (undirected projection), PageRank, greedy
modularity communities, composite influence, bridge detection, observed
propagation paths. Aggregated server-side before rendering.

---

## Technology stack

**Backend** — Python 3.12, FastAPI, SQLAlchemy 2, Pydantic v2, NetworkX, SQLite
**Frontend** — Next.js 15 (App Router), React 19, TypeScript, Tailwind CSS,
Recharts, Cytoscape.js, lucide-react
**Testing** — pytest (backend), Vitest + Testing Library (frontend)

---

## Configuring AI

Default is `local` — a deterministic rule/lexicon engine requiring no key,
no model download and no network.

```bash
AI_PROVIDER=local     # default
AI_PROVIDER=openai    # requires AI_API_KEY
AI_API_KEY=sk-...
AI_MODEL=gpt-4o-mini
```

With `openai`, the local engine still runs first and the LLM result is discarded
unless it validates against the expected schema, so a provider outage degrades
to a working result rather than an error. Add a provider by implementing
`AIProvider` and registering it in `ai/registry.py`.

---

## Connecting real social APIs

Every adapter declares its credentials and its payload mapping. Supply
credentials in `.env` and that platform switches from demo to live; nothing
downstream changes.

| Platform | Variables | Library |
|---|---|---|
| X | `X_BEARER_TOKEN` | httpx (API v2, implemented) |
| Telegram | `TELEGRAM_API_ID`, `TELEGRAM_API_HASH` | Telethon (MTProto session required) |
| Instagram | `INSTAGRAM_ACCESS_TOKEN` | Graph API (Business account) |
| Facebook | `FACEBOOK_ACCESS_TOKEN` | Graph API (Page token) |
| Reddit | `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET` | PRAW |
| YouTube | `YOUTUBE_API_KEY` | Data API v3 (implemented) |

An adapter without credentials reports `NOT_CONNECTED` and returns an empty
batch with an explanation. **It never fabricates connectivity.** The
`normalize()` mapping functions are unit-tested against realistic payloads even
though the demo never touches the network.

---

## API reference

Interactive docs at `http://127.0.0.1:8000/docs`.

All analytical endpoints accept the same filters: `range` (`1h`…`7d`/`all`) or
`start`/`end`, `platforms`, `topics`, `segments`, `sentiments`, `emotions`,
`search`, `granularity`.

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/health` | Status, demo mode, AI provider, last run |
| GET | `/api/meta/filters` | Filter options derived from stored data |
| GET | `/api/overview` | KPIs, distributions, Audience Pulse, recommendations |
| GET | `/api/sentiment/timeline` | Bucketed sentiment time series |
| GET | `/api/trends` | Ranked trends with velocity and momentum |
| GET | `/api/trends/{topic_id}` | One trend |
| GET | `/api/topics/{topic_id}` | Full deep dive |
| GET | `/api/topics/{topic_id}/journey` | Narrative Journey milestones |
| GET | `/api/topics/{topic_id}/platforms` | Cross-platform divergence + flow |
| GET | `/api/audience` | Segments + aggregate demographics |
| GET | `/api/audience/compare` | Side-by-side segment comparison |
| GET | `/api/audience/{segment_id}` | One segment |
| GET | `/api/network` | Aggregated graph |
| GET | `/api/network/influencers` | Influence ranking |
| GET | `/api/network/flow/{topic_id}` | Observed propagation |
| GET | `/api/intelligence` | Intelligence cards |
| GET | `/api/intelligence/recommendations` | Derived recommendations |
| GET | `/api/timeline` | Chronological event log |
| GET | `/api/posts` | Paginated posts with analysis |
| GET | `/api/search` | Global search |
| GET | `/api/sources` | Adapter status |
| POST | `/api/ingestion/demo` | Load demo dataset + run pipeline |
| POST | `/api/ingestion/reset` | Clear, regenerate, recompute |
| POST | `/api/analyze` | Run the NLP engine on arbitrary text |
| GET | `/api/runs/latest` | Last run with stage timings and validation |

---

## Database model

Twelve tables. Every analytical result is traceable to the rows it came from.

`data_sources` · `users` · `posts` · `interactions` · `topics` · `post_topics` ·
`sentiment_results` · `demographic_profiles` · `audience_segments` ·
`author_segments` · `trend_metrics` · `network_metrics` · `intelligence_events` ·
`analysis_runs`

SQLite by default. Switching to PostgreSQL is a `DATABASE_URL` change plus a
driver — no code change.

---

## Testing

```bash
cd backend
.venv\Scripts\python -m pytest -q
```

```bash
cd frontend
npm run test
```

```bash
cd frontend
npm run typecheck
```

```bash
cd frontend
npm run build
```

Backend coverage includes adapter normalisation against realistic payloads,
sarcasm reversal, Hinglish, negation and intensifiers, trend maths and
classification boundaries, momentum forecasting, network centrality and bridge
detection, segmentation prototypes, demographic confidence bounds, topic
classification, the end-to-end pipeline, seed validation, filter
synchronisation, and the API contract including error states.

**Seed validation** runs automatically after every load and asserts real
properties of what was stored: minimum posts, multiple platforms, multiple
topics, sentiment distribution, interaction graph, populated segments, at least
one accelerating trend, influencers, bridge nodes, a cross-platform topic, and
detected sarcasm.

---

## Privacy and ethics

- **Public data only.** No adapter requests private-message scopes.
- **No private-message analysis.** Telegram ingestion covers public channels only.
- **Aggregate demographics.** Individual rows exist for traceability, not profiling.
- **No sensitive attributes.** No health, religion, sexuality or political inference.
- **No claimed certainty.** Every inference carries a confidence band and its evidence.
- **Pseudonymous identifiers.** Accounts appear as `A4193` throughout the analytical UI.
- **No causal claims.** Language stays correlational: *preceded*, *likely driver*,
  *appears to originate from*, *associated with*.
- **Platform terms respected.** Official APIs with the platform's own credentials.

A dedicated `/privacy` page states each commitment alongside where it is enforced.

---

## Design decisions

**Why a rule engine instead of a transformer?** It runs with zero setup, is
deterministic, and — critically — can explain itself term by term, which is what
the evidence layer needs. The `AIProvider` interface means swapping in a
fine-tuned model (mBERT, HingBERT, RoBERTa) is one class.

**Why re-derive intelligence under filters?** A detection computed over every
platform, displayed next to KPIs for one platform, presents two different
datasets as one view. When a filter is active the detectors re-run against that
subset.

**Why an evidence discount on trend scores?** Percentage growth off a small base
is cheap. Without it a topic going 5 → 70 outranks one going 11 → 545 purely on
percentages.

**Why undirected betweenness?** On a directed graph an account that only mentions
others scores zero, systematically hiding the brokering accounts bridge
detection exists to find.

**Why episode detection in the Narrative Journey?** A topic can carry weeks of
background chatter. Measuring "first activity" against that makes whichever
platform is chattiest at baseline look like the origin.

---

## Future improvements

- Fine-tuned multilingual sentiment (HingBERT/mBERT) behind the same interface
- Live streaming ingestion with incremental recomputation
- Louvain/Leiden community detection at larger graph scale
- Coordinated-behaviour detection (near-duplicate text, synchronised posting)
- Claim-level misinformation tracking with source attribution
- PostgreSQL + TimescaleDB for multi-month retention
- Alerting when a detection crosses a configured severity

---

## Licence & attribution

Built as a Smart India Hackathon 2026 submission. All demo content is fictional:
the products, accounts, posts and the incident are synthetic. Any resemblance to
real products or accounts is coincidental.
