defmodule SurveyPulse.ClickHouseCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import SurveyPulse.ClickHouseCase
    end
  end

  setup do
    SurveyPulse.ClickRepo.query!("TRUNCATE TABLE responses")
    SurveyPulse.ClickRepo.query!("TRUNCATE TABLE wave_question_metrics")
    :ok
  end

  def insert_responses!(survey_id, wave_id, question_id, scores, opts \\ []) do
    age_group = Keyword.get(opts, :age_group, "25-34")
    gender = Keyword.get(opts, :gender, "male")
    region = Keyword.get(opts, :region, "north_america")

    rows =
      Enum.map(scores, fn score ->
        %{
          id: Ecto.UUID.generate(),
          survey_id: survey_id,
          wave_id: wave_id,
          question_id: question_id,
          respondent_id: Ecto.UUID.generate(),
          score: score,
          age_group: age_group,
          gender: gender,
          region: region,
          responded_at: DateTime.utc_now()
        }
      end)

    SurveyPulse.Analytics.ingest_responses!(rows)
    rows
  end
end
