# AGENTS.md — SurveyPulse

## Architecture

SurveyPulse is a dual-database survey analytics dashboard built with Elixir.

- **PostgreSQL** (OLTP): Surveys, waves, questions — managed via Ash + AshPostgres
- **ClickHouse** (OLAP): Response data, aggregated metrics — accessed via ecto_ch with Ash ManualRead actions

## Domains

### `SurveyPulse.Surveys` (PostgreSQL)
- `Survey`, `Wave`, `Question` resources
- Code interfaces defined at the domain level with `define`
- All query logic lives inside Ash actions (no piping into `Ash.read`)

### `SurveyPulse.Analytics` (ClickHouse)
- `Response` — generic `:ingest` action for batch writes via `ClickRepo.insert_all`
- `WaveSummary` — ManualRead that queries `wave_question_metrics` materialized view
- `Trend` — ManualRead that computes wave-over-wave deltas with significance annotations

## Conventions

- **Ash-first**: Every domain operation goes through Ash. No raw Ecto queries for PG data.
- **Domain code interfaces**: `define` calls live on the domain, not on resources.
- **Action-embedded logic**: Filters, sorts, and business logic live inside Ash actions.
- **ClickHouse queries**: Use parameterized queries with `{param:Type}` syntax for safety.

## Key Commands

```bash
docker compose up          # Start everything (PG, ClickHouse, app)
mix setup                  # Install deps, migrate, seed
mix test                   # Run tests (excludes ClickHouse tests)
mix test --include clickhouse  # Run all tests including ClickHouse
mix credo --strict         # Lint
mix format                 # Format
```

## Ports

- App: 4600 (dev, test: 4602, prod, Docker)
- PostgreSQL: 5434 (host) → 5432 (container)
- ClickHouse: 8123

## Testing

- PostgreSQL tests use `Ecto.Adapters.SQL.Sandbox`
- ClickHouse tests are tagged `@tag :clickhouse` and excluded by default
- LiveView tests use `Phoenix.LiveViewTest`

## Project Structure

```
lib/
├── survey_pulse/
│   ├── surveys/           # Ash domain + PG resources
│   ├── analytics/         # Ash domain + ClickHouse resources
│   │   └── manual_reads/  # ManualRead modules for ClickHouse
│   ├── ingestion/         # Broadway pipeline + processor
│   ├── seeds.ex           # Realistic demo data generator
│   └── release.ex         # Release tasks (migrate, seed)
└── survey_pulse_web/
    ├── live/              # DashboardLive, SurveyLive
    └── controllers/api/   # IngestController
```
