# SurveyPulse

A production-grade survey analytics dashboard built with Elixir, Ash Framework, Phoenix LiveView, and ClickHouse. Demonstrates longitudinal (wave-over-wave) trend analysis with real-time updates and demographic filtering.

## Quick Start

```bash
docker compose up
```

Visit [http://localhost:4600](http://localhost:4600) — the dashboard loads with pre-seeded data showing 3 surveys, ~97K responses, and visible trend patterns.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  LiveView    │────▶│  Ash Domain  │────▶│ PostgreSQL  │
│  Dashboard   │     │  (Surveys)   │     │  (OLTP)     │
└─────────────┘     └──────────────┘     └─────────────┘
       │
       │            ┌──────────────┐     ┌─────────────┐
       └───────────▶│  Ash Domain  │────▶│ ClickHouse  │
                    │  (Analytics) │     │  (OLAP)     │
                    └──────────────┘     └─────────────┘
                           ▲
                    ┌──────┴───────┐
                    │   Broadway   │
                    │  (Ingestion) │
                    └──────────────┘
```

### Why Two Databases?

- **PostgreSQL**: Stores survey metadata (surveys, waves, questions). Managed by Ash + AshPostgres with migrations, relationships, and aggregates.
- **ClickHouse**: Stores individual responses (~97K rows). Uses MergeTree for raw data and AggregatingMergeTree materialized views for pre-computed metrics. Queries return in milliseconds.

### Why Ash Framework?

Ash provides a declarative resource layer that keeps domain logic organized:
- Code interfaces at the domain level (`SurveyPulse.Surveys.list_surveys!()`)
- Custom actions with embedded query logic (no scattered context modules)
- ManualRead pattern for ClickHouse integration within the Ash ecosystem

### Why Broadway?

The ingestion pipeline uses Broadway with a DummyProducer pattern — external sources push messages in via `Pipeline.ingest/1`. This demonstrates:
- Batch processing (5K rows per ClickHouse insert)
- Concurrent processors with validation
- Production-ready message acknowledgment

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Elixir 1.18 / OTP 27 |
| Framework | Phoenix 1.8, LiveView 1.1 |
| Domain Layer | Ash 3.x |
| OLTP Database | PostgreSQL 16 |
| OLAP Database | ClickHouse 24.8 |
| Ingestion | Broadway |
| Charts | Chart.js |
| CSS | Tailwind v4 |
| HTTP Server | Bandit |

## Features

- **Dashboard** (`/`): Survey cards with top-line KPIs (response count, avg score, trend delta), live update indicator
- **Survey Deep-Dive** (`/surveys/:id`): Wave-over-wave trend chart, question selector tabs, demographic filters (age, gender, region), wave detail table with significance annotations
- **Real-time**: PubSub broadcasts on new data trigger LiveView re-renders
- **Seed Data**: 3 surveys with realistic patterns — gradual improvement trend with a visible dip at waves 4-5 (simulating campaign fatigue)

## Development

```bash
# Start databases
docker compose up -d postgres clickhouse

# Install and setup
mix setup

# Run dev server
mix phx.server

# Run tests
mix test

# Quality checks
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
```

## API

### Ingest Responses

```bash
curl -X POST http://localhost:4600/api/ingest \
  -H "Content-Type: application/json" \
  -d '{"responses": [{"survey_id": "...", "wave_id": "...", "question_id": "...", "respondent_id": "...", "score": 4, "age_group": "25-34", "gender": "female", "region": "europe"}]}'
```

## What I'd Do Next

- **Authentication**: Add user auth with AshAuthentication
- **CSV Export**: Download filtered trend data
- **Alerting**: Notify on statistically significant score drops
- **A/B Comparison**: Side-by-side wave comparison view
- **ETS Caching**: Cache ClickHouse aggregations with TTL for dashboard performance
- **OpenTelemetry**: Full distributed tracing (instrumentation hooks are in place)
