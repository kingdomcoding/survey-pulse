defmodule SurveyPulse.Analytics.ManualReads.ReadWaveSummary do
  use Ash.Resource.ManualRead

  @impl true
  def read(query, _data_layer_query, _opts, _context) do
    survey_id = query.arguments.survey_id
    filters = Map.get(query.arguments, :filters, %{})

    {where_clauses, params} = build_filters(survey_id, filters)

    sql = """
    SELECT
      wave_id,
      question_id,
      countMerge(response_count) AS response_count,
      round(avgMerge(avg_score), 2) AS avg_score,
      minMerge(min_score) AS min_score,
      maxMerge(max_score) AS max_score
    FROM wave_question_metrics
    WHERE #{where_clauses}
    GROUP BY wave_id, question_id
    ORDER BY wave_id, question_id
    """

    case SurveyPulse.ClickRepo.query(sql, params) do
      {:ok, %{rows: rows, columns: columns}} ->
        results =
          Enum.map(rows, fn row ->
            map =
              columns
              |> Enum.zip(row)
              |> Map.new(fn {col, val} -> {String.to_existing_atom(col), val} end)

            struct!(SurveyPulse.Analytics.WaveSummary, map)
          end)

        {:ok, results}

      {:error, reason} ->
        {:error,
         Ash.Error.Query.InvalidQuery.exception(message: "ClickHouse error: #{inspect(reason)}")}
    end
  end

  defp build_filters(survey_id, filters) do
    base = {"survey_id = {survey_id:UUID}", %{"survey_id" => survey_id}}

    Enum.reduce(filters, base, fn
      {:age_group, value}, {clauses, params} when value != "all" ->
        {clauses <> " AND age_group = {age_group:String}", Map.put(params, "age_group", value)}

      {:gender, value}, {clauses, params} when value != "all" ->
        {clauses <> " AND gender = {gender:String}", Map.put(params, "gender", value)}

      {:region, value}, {clauses, params} when value != "all" ->
        {clauses <> " AND region = {region:String}", Map.put(params, "region", value)}

      _, acc ->
        acc
    end)
  end
end
