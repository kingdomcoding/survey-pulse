defmodule SurveyPulse.ClickRepo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :survey_pulse,
    adapter: Ecto.Adapters.ClickHouse
end
