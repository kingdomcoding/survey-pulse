# SurveyPulse

## Architecture
- Dual-database: PostgreSQL (Ash/Ecto OLTP) + ClickHouse (OLAP analytics)
- Broadway pipeline for response ingestion with batched ClickHouse writes
- Phoenix LiveView with Chart.js hooks for real-time dashboards
- Ash Framework domains: Surveys (CRUD) and Analytics (ManualRead over ClickHouse)

## Conventions
- `mix format` before committing
- No unnecessary comments or typespecs on private functions
- ClickHouse queries: parameterized via named parameters, never string-interpolated
- Ash resources: ManualRead for ClickHouse, AshPostgres for transactional data
- Tests: ClickHouse tests use truncation between runs, tagged @moduletag :clickhouse
- Commits: small, atomic, trunk-based

## Running
- `docker compose up -d --build` starts everything
- Seeds run automatically on first boot
- PostgreSQL on port 5434, ClickHouse on port 8123, app on port 4600

## Testing
- `mix test` — unit tests only
- `mix test --include clickhouse` — full suite (needs running ClickHouse)

## Key Patterns
- ManualRead actions execute raw ClickHouse SQL, return Ash resource structs
- Broadway DummyProducer with push-based ingestion via Pipeline.ingest/1
- PubSub broadcasts on response ingestion, LiveViews subscribe for real-time updates
- Sample data generator uses scale-relative effects for realistic patterns
