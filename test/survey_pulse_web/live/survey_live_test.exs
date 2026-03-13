defmodule SurveyPulseWeb.SurveyLiveTest do
  use SurveyPulseWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    survey =
      SurveyPulse.Surveys.create_survey!(%{
        name: "Deep Dive Test",
        description: "Testing survey detail",
        category: :ad_testing
      })

    question =
      SurveyPulse.Surveys.create_question!(%{
        survey_id: survey.id,
        code: "RECALL",
        text: "How memorable?",
        question_type: :likert,
        scale_min: 1,
        scale_max: 5
      })

    SurveyPulse.Surveys.create_wave!(%{
      survey_id: survey.id,
      wave_number: 1,
      label: "Jan 2025",
      started_at: ~U[2025-01-01 00:00:00Z]
    })

    %{survey: survey, question: question}
  end

  test "renders survey detail page", %{conn: conn, survey: survey} do
    {:ok, _view, html} = live(conn, ~p"/surveys/#{survey.id}")

    assert html =~ survey.name
    assert html =~ survey.description
    assert html =~ "Ad Testing"
    assert html =~ "Score Over Time"
    assert html =~ "Round-by-Round Detail"
  end

  test "shows question tabs", %{conn: conn, survey: survey, question: question} do
    {:ok, _view, html} = live(conn, ~p"/surveys/#{survey.id}")
    assert html =~ question.code
  end

  test "shows filter dropdowns", %{conn: conn, survey: survey} do
    {:ok, _view, html} = live(conn, ~p"/surveys/#{survey.id}")
    assert html =~ "All Ages"
    assert html =~ "All Genders"
    assert html =~ "All Regions"
  end

  test "has back link to dashboard", %{conn: conn, survey: survey} do
    {:ok, view, _html} = live(conn, ~p"/surveys/#{survey.id}")
    assert has_element?(view, "a[href='/']")
  end
end
