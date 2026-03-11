defmodule SurveyPulseWeb.DashboardLiveTest do
  use SurveyPulseWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    survey =
      SurveyPulse.Surveys.create_survey!(%{
        name: "Test Brand Tracker",
        description: "Testing dashboard",
        category: :brand_health
      })

    SurveyPulse.Surveys.create_wave!(%{
      survey_id: survey.id,
      wave_number: 1,
      label: "Jan 2025",
      started_at: ~U[2025-01-01 00:00:00Z]
    })

    %{survey: survey}
  end

  test "renders dashboard with survey cards", %{conn: conn, survey: survey} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "SurveyPulse"
    assert html =~ "Consumer insights dashboard"
    assert html =~ survey.name
    assert html =~ "Brand Health"
    assert has_element?(view, "a[href='/surveys/#{survey.id}']")
  end

  test "displays live indicator", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Live"
  end
end
