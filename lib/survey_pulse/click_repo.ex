defmodule SurveyPulse.ClickRepo do
  use Ecto.Repo,
    otp_app: :survey_pulse,
    adapter: Ecto.Adapters.ClickHouse
end
