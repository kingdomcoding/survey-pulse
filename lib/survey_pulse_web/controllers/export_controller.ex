defmodule SurveyPulseWeb.ExportController do
  use SurveyPulseWeb, :controller

  def export(conn, %{"id" => survey_id} = params) do
    survey = SurveyPulse.Surveys.get_survey!(survey_id, load: [:questions])

    question_id =
      params["question"] || (List.first(survey.questions) && List.first(survey.questions).id)

    filters = %{
      age_group: params["age_group"] || "all",
      gender: params["gender"] || "all",
      region: params["region"] || "all"
    }

    trend_data =
      if filters == %{age_group: "all", gender: "all", region: "all"} do
        SurveyPulse.Analytics.longitudinal_trend!(survey_id, question_id)
      else
        SurveyPulse.Analytics.longitudinal_trend_filtered!(survey_id, question_id, filters)
      end

    question = Enum.find(survey.questions, &(&1.id == question_id))
    safe_name = String.replace(survey.name, ~r/[^a-zA-Z0-9]/, "_")
    filename = "#{safe_name}_#{question && question.code}_export.csv"

    csv =
      [
        [
          "Round",
          "Responses",
          "Avg Score",
          "Top2 Box %",
          "Bottom2 Box %",
          "Delta",
          "Significant?"
        ]
      ]
      |> Enum.concat(
        Enum.map(trend_data, fn row ->
          [
            row.wave_label,
            row.response_count,
            row.avg_score,
            row.top2_box,
            row.bot2_box,
            row.delta,
            row.significant?
          ]
        end)
      )
      |> Enum.map_join("\n", &Enum.join(&1, ","))

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end
end
