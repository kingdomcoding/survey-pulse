defmodule SurveyPulse.Analytics.BreakdownTest do
  use SurveyPulse.ClickHouseCase
  use SurveyPulse.DataCase

  @moduletag :clickhouse

  setup do
    survey =
      SurveyPulse.Surveys.create_survey!(%{
        name: "Breakdown Test",
        description: "Test",
        category: :brand_health
      })

    question =
      SurveyPulse.Surveys.create_question!(%{
        survey_id: survey.id,
        code: "Q1",
        text: "Test",
        question_type: :likert,
        scale_min: 1,
        scale_max: 5
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

  test "breaks down by age_group", ctx do
    insert_responses!(ctx.survey.id, ctx.wave.id, ctx.question.id, List.duplicate(5, 30),
      age_group: "18-24"
    )

    insert_responses!(ctx.survey.id, ctx.wave.id, ctx.question.id, List.duplicate(2, 30),
      age_group: "65+"
    )

    Process.sleep(500)

    breakdown =
      SurveyPulse.Analytics.demographic_breakdown!(
        ctx.survey.id,
        ctx.question.id,
        ctx.wave.id,
        :age_group
      )

    young = Enum.find(breakdown, &(&1.segment == "18-24"))
    old = Enum.find(breakdown, &(&1.segment == "65+"))

    assert young.avg_score == 5.0
    assert old.avg_score == 2.0
    assert young.response_count == 30
  end

  test "breaks down by region", ctx do
    insert_responses!(ctx.survey.id, ctx.wave.id, ctx.question.id, List.duplicate(4, 20),
      region: "europe"
    )

    insert_responses!(ctx.survey.id, ctx.wave.id, ctx.question.id, List.duplicate(3, 20),
      region: "asia_pacific"
    )

    Process.sleep(500)

    breakdown =
      SurveyPulse.Analytics.demographic_breakdown!(
        ctx.survey.id,
        ctx.question.id,
        ctx.wave.id,
        :region
      )

    assert length(breakdown) == 2
    europe = Enum.find(breakdown, &(&1.segment == "europe"))
    assert europe.avg_score == 4.0
  end
end
