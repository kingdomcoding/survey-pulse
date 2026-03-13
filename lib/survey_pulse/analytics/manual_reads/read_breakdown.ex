defmodule SurveyPulse.Analytics.ManualReads.ReadBreakdown do
  use Ash.Resource.ManualRead

  @impl true
  def read(query, _data_layer_query, _opts, _context) do
    survey_id = query.arguments.survey_id
    question_id = query.arguments.question_id
    wave_id = query.arguments.wave_id
    dim_col = Atom.to_string(query.arguments.dimension)

    sql = """
    SELECT
      #{dim_col} AS segment,
      round(avg(score), 2) AS avg_score,
      count(*) AS response_count,
      round(countIf(score >= 4) / count(*) * 100, 1) AS top2_box
    FROM responses
    WHERE survey_id = {survey_id:UUID}
      AND question_id = {question_id:UUID}
      AND wave_id = {wave_id:UUID}
    GROUP BY segment
    ORDER BY segment
    """

    params = %{
      "survey_id" => survey_id,
      "question_id" => question_id,
      "wave_id" => wave_id
    }

    case SurveyPulse.ClickRepo.query(sql, params) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [seg, avg, cnt, t2b] ->
            struct!(SurveyPulse.Analytics.Breakdown, %{
              segment: seg,
              avg_score: avg,
              response_count: cnt,
              top2_box: t2b
            })
          end)

        {:ok, results}

      _ ->
        {:ok, []}
    end
  end
end
