import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :survey_pulse, SurveyPulse.Repo,
  username: "survey_pulse",
  password: "survey_pulse",
  hostname: "localhost",
  port: 5434,
  database: "survey_pulse_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :survey_pulse, SurveyPulse.ClickRepo,
  url: "http://survey_pulse:survey_pulse@localhost:8123/survey_pulse_test"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :survey_pulse, SurveyPulseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4602],
  secret_key_base: "BIRZNgDRba6Y8mP5AQqP3UCEiiOoYzM3CrmvrnBFheQqm3ow5lAN1oJ6vfL0bJIS",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
