defmodule SurveyPulse.Analytics.ManualReads.ReadWaveSummary do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Ash.Error.Query.InvalidQuery
  alias SurveyPulse.Analytics.WaveSummary

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
        {:ok, Enum.map(rows, &row_to_struct(columns, &1))}

      {:error, reason} ->
        {:error, InvalidQuery.exception(message: "ClickHouse error: #{inspect(reason)}")}
    end
  end

  defp row_to_struct(columns, row) do
    map =
      columns
      |> Enum.zip(row)
      |> Map.new(fn {col, val} -> {String.to_existing_atom(col), val} end)

    struct!(WaveSummary, map)
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
