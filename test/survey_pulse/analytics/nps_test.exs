defmodule SurveyPulse.Analytics.NpsTest do
  use SurveyPulse.ClickHouseCase
  use SurveyPulse.DataCase

  @moduletag :clickhouse

  setup do
    survey =
      SurveyPulse.Surveys.create_survey!(%{
        name: "NPS Test",
        description: "Test",
        category: :brand_health
      })

    question =
      SurveyPulse.Surveys.create_question!(%{
        survey_id: survey.id,
        code: "NPS1",
        text: "Would you recommend?",
        question_type: :nps,
        scale_min: 0,
        scale_max: 10
      })

    wave =
      SurveyPulse.Surveys.create_wave!(%{
        survey_id: survey.id,
        wave_number: 1,
        label: "R1",
        started_at: ~U[2025-01-01 00:00:00Z],
        ended_at: ~U[2025-01-14 00:00:00Z]
      })

    %{survey: survey, question: question, wave: wave}
  end

  test "computes NPS correctly", ctx do
    promoters = List.duplicate(9, 20) ++ List.duplicate(10, 20)
    passives = List.duplicate(7, 15) ++ List.duplicate(8, 15)
    detractors = List.duplicate(3, 15) ++ List.duplicate(5, 15)
    scores = promoters ++ passives ++ detractors

    insert_responses!(ctx.survey.id, ctx.wave.id, ctx.question.id, scores)
    Process.sleep(500)

    [point] = SurveyPulse.Analytics.longitudinal_trend!(ctx.survey.id, ctx.question.id)

    assert point.avg_score == 10.0
    assert point.response_count == 100
  end

  test "all detractors produces NPS of -100", ctx do
    insert_responses!(ctx.survey.id, ctx.wave.id, ctx.question.id, List.duplicate(3, 50))
    Process.sleep(500)

    [point] = SurveyPulse.Analytics.longitudinal_trend!(ctx.survey.id, ctx.question.id)
    assert point.avg_score == -100.0
  end
end
