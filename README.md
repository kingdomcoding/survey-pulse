[![CI](https://github.com/kingdomcoding/survey-pulse/actions/workflows/ci.yml/badge.svg)](https://github.com/kingdomcoding/survey-pulse/actions/workflows/ci.yml)

# SurveyPulse

A dual-database survey analytics dashboard built with Elixir, Phoenix LiveView, ClickHouse, and PostgreSQL. Demonstrates the architecture patterns used in longitudinal survey analytics — turning large-scale response data into actionable insights across survey waves.

## Architecture

```
                ┌─────────────────────────────────────────────────────┐
                │                  Phoenix LiveView                   │
                │  DashboardLive ── SurveyLive ── SurveyFormComponent │
                │       │               │                             │
                │    SparkLine      TrendChart + BreakdownChart       │
                │   (Chart.js)       (Chart.js hooks)                 │
                └─────────┬───────────────┬───────────────────────────┘
                          │               │
              ┌───────────▼───────────────▼──────────┐
              │         Ash Framework Domains         │
              │  Surveys (CRUD)    Analytics (reads)  │
              └────────┬──────────────────┬───────────┘
                       │                  │
            ┌──────────▼────┐    ┌────────▼──────────┐
            │  PostgreSQL   │    │    ClickHouse      │
            │  surveys      │    │  responses         │
            │  questions    │    │  wave_question_     │
            │  waves        │    │    metrics (AggMT)  │
            └───────────────┘    │  materialized view  │
                                 └─────────────────────┘
                                         ▲
                                         │
              ┌──────────────────────────┤
              │     Broadway Pipeline    │
              │  validate → batch → insert
              └──────────▲───────────────┘
                         │
              Pipeline.ingest/1 (push-based)
```

## Key Technical Decisions

- **Dual-database architecture**: PostgreSQL for application state (surveys, questions, waves via Ash/Ecto), ClickHouse for analytics at scale. OLTP and OLAP workloads have fundamentally different access patterns — mixing them in one database forces compromise on both.

- **AggregatingMergeTree with materialized views**: Pre-aggregates response metrics on insert using `countState()`/`avgState()`. Reads use `countMerge()`/`avgMerge()` for sub-second analytics regardless of response volume. No background jobs, no cron — the materialized view keeps aggregations current automatically.

- **Broadway for ingestion**: Back-pressure, automatic batching (5K rows), concurrent validation (4 processors), fault tolerance via supervision. All data — seed generation and live simulation — flows through the Broadway pipeline. Responses go through validation → batching → ClickHouse insert → PubSub broadcast.

- **Ash Framework with ManualRead**: Ash resources serve as typed interfaces over raw ClickHouse SQL, preserving Ash's action system while bypassing Ecto for OLAP queries. Domain boundaries: `Surveys` (CRUD) and `Analytics` (read-only).

- **LiveView over React**: Real-time PubSub-driven chart updates with no API layer, no client state management, no WebSocket boilerplate. Chart.js hooks handle rendering; LiveView handles data flow.

## Features

- **Dashboard**: Survey cards with top-line KPIs, sparkline trend charts, live update indicator
- **Survey Deep-Dive**: Wave-over-wave trend chart with significance markers, question comparison overlay, demographic breakdown with inline score labels
- **Demographic Filtering**: Filter by age group, gender, region — all queries parameterized and pushed to ClickHouse
- **Live Ingestion Simulation**: Click "Simulate Live Data" to watch Broadway ingest responses in real-time, with charts updating via PubSub
- **Statistical Testing**: Z-test significance annotations on wave-over-wave changes, NPS computation (promoters vs detractors), top-2-box / bottom-2-box percentages
- **CSV Export**: Download filtered trend data for offline analysis

## Running Locally

```bash
docker compose up -d --build
```

App runs at http://localhost:4600. Seeds 9 surveys with 120K+ simulated responses automatically on first boot.

## Running Tests

```bash
# Unit tests (no ClickHouse required)
mix test

# Full test suite including ClickHouse integration
mix test --include clickhouse
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Elixir 1.18 / OTP 27 |
| Framework | Phoenix 1.8, LiveView 1.1 |
| Domain Layer | Ash 3.x |
| OLTP Database | PostgreSQL 16 |
| OLAP Database | ClickHouse 24.8 |
| Ingestion | Broadway |
| Charts | Chart.js + chartjs-plugin-datalabels |
| CSS | Tailwind v4 |

## What I'd Build Next

- **OpenTelemetry tracing** on ClickHouse queries and Broadway stages for production observability
- **Kubernetes deployment** with horizontal pod autoscaling based on Broadway queue depth
- **Query result caching** with ETS + TTL for expensive aggregations that don't change mid-wave
- **Alerting on significant trend shifts** — push notifications when z-test detects a statistically significant change
