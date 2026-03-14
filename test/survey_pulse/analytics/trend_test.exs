defmodule SurveyPulse.Analytics.TrendTest do
  use SurveyPulse.ClickHouseCase
  use SurveyPulse.DataCase

  @moduletag :clickhouse

  setup do
    survey =
      SurveyPulse.Surveys.create_survey!(%{
        name: "Trend Test",
        description: "Test",
        category: :brand_health
      })

    question =
      SurveyPulse.Surveys.create_question!(%{
        survey_id: survey.id,
        code: "Q1",
        text: "Test question",
        question_type: :likert,
        scale_min: 1,
        scale_max: 5
      })

    wave1 =
      SurveyPulse.Surveys.create_wave!(%{
        survey_id: survey.id,
        wave_number: 1,
        label: "R1 · Jan 2025",
        started_at: ~U[2025-01-01 00:00:00Z],
        ended_at: ~U[2025-01-14 00:00:00Z]
      })

    wave2 =
      SurveyPulse.Surveys.create_wave!(%{
        survey_id: survey.id,
        wave_number: 2,
        label: "R2 · Feb 2025",
        started_at: ~U[2025-02-01 00:00:00Z],
        ended_at: ~U[2025-02-14 00:00:00Z]
      })

    %{survey: survey, question: question, wave1: wave1, wave2: wave2}
  end

  test "computes wave-over-wave trend with deltas", ctx do
    insert_responses!(ctx.survey.id, ctx.wave1.id, ctx.question.id, List.duplicate(3, 100))
    insert_responses!(ctx.survey.id, ctx.wave2.id, ctx.question.id, List.duplicate(4, 100))
    Process.sleep(500)

    trend = SurveyPulse.Analytics.longitudinal_trend!(ctx.survey.id, ctx.question.id)

    assert length(trend) == 2
    [first, second] = trend
    assert first.wave_number == 1
    assert first.avg_score == 3.0
    assert first.delta == 0.0
    assert second.wave_number == 2
    assert second.avg_score == 4.0
    assert second.delta == 1.0
  end

  test "marks large changes as significant", ctx do
    wave1_scores = List.duplicate(2, 100) ++ List.duplicate(3, 100)
    wave2_scores = List.duplicate(4, 100) ++ List.duplicate(5, 100)
    insert_responses!(ctx.survey.id, ctx.wave1.id, ctx.question.id, wave1_scores)
    insert_responses!(ctx.survey.id, ctx.wave2.id, ctx.question.id, wave2_scores)
    Process.sleep(500)

    [_first, second] = SurveyPulse.Analytics.longitudinal_trend!(ctx.survey.id, ctx.question.id)
    assert second.significant? == true
  end

  test "does not mark small changes as significant", ctx do
    insert_responses!(ctx.survey.id, ctx.wave1.id, ctx.question.id, List.duplicate(3, 100))
    insert_responses!(ctx.survey.id, ctx.wave2.id, ctx.question.id, List.duplicate(3, 100))
    Process.sleep(500)

    [_first, second] = SurveyPulse.Analytics.longitudinal_trend!(ctx.survey.id, ctx.question.id)
    assert second.significant? == false
  end

  test "computes top2_box and bot2_box percentages", ctx do
    scores = List.duplicate(5, 50) ++ List.duplicate(4, 50) ++ List.duplicate(1, 50)
    insert_responses!(ctx.survey.id, ctx.wave1.id, ctx.question.id, scores)
    Process.sleep(500)

    [point] = SurveyPulse.Analytics.longitudinal_trend!(ctx.survey.id, ctx.question.id)
    assert point.top2_box >= 66.0
    assert point.bot2_box >= 30.0
  end

  test "respects demographic filters", ctx do
    insert_responses!(ctx.survey.id, ctx.wave1.id, ctx.question.id, List.duplicate(5, 50),
      age_group: "18-24"
    )

    insert_responses!(ctx.survey.id, ctx.wave1.id, ctx.question.id, List.duplicate(1, 50),
      age_group: "65+"
    )

    Process.sleep(500)

    [all] = SurveyPulse.Analytics.longitudinal_trend!(ctx.survey.id, ctx.question.id)
    assert all.avg_score == 3.0

    [young] =
      SurveyPulse.Analytics.longitudinal_trend_filtered!(
        ctx.survey.id,
        ctx.question.id,
        %{age_group: "18-24"}
      )

    assert young.avg_score == 5.0
  end
end
