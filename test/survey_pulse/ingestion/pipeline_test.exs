defmodule SurveyPulse.Ingestion.PipelineTest do
  use SurveyPulse.ClickHouseCase
  use SurveyPulse.DataCase

  @moduletag :clickhouse

  test "messages flow through Broadway into ClickHouse" do
    survey_id = Ecto.UUID.generate()
    wave_id = Ecto.UUID.generate()
    question_id = Ecto.UUID.generate()

    responses =
      for i <- 1..10 do
        %{
          survey_id: survey_id,
          wave_id: wave_id,
          question_id: question_id,
          respondent_id: Ecto.UUID.generate(),
          score: rem(i, 10),
          age_group: "25-34",
          gender: "male",
          region: "europe",
          responded_at: DateTime.utc_now()
        }
      end

    SurveyPulse.Ingestion.Pipeline.ingest(responses)
    Process.sleep(3_000)

    {:ok, %{rows: [[count]]}} =
      SurveyPulse.ClickRepo.query(
        "SELECT count(*) FROM responses WHERE survey_id = {sid:UUID}",
        %{"sid" => survey_id}
      )

    assert count == 10
  end

  test "invalid responses are rejected by Broadway" do
    responses = [
      %{survey_id: nil, wave_id: nil, question_id: nil, respondent_id: nil, score: 999}
    ]

    SurveyPulse.Ingestion.Pipeline.ingest(responses)
    Process.sleep(3_000)

    {:ok, %{rows: [[count]]}} =
      SurveyPulse.ClickRepo.query("SELECT count(*) FROM responses", %{})

    assert count == 0
  end
end
