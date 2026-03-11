defmodule SurveyPulse.Analytics.ManualReads.ReadTrend do
  use Ash.Resource.ManualRead

  @impl true
  def read(query, _data_layer_query, _opts, _context) do
    survey_id = query.arguments.survey_id
    question_id = query.arguments.question_id
    filters = Map.get(query.arguments, :filters, %{})

    {where_clauses, params} = build_filters(survey_id, question_id, filters)

    sql = """
    SELECT
      wave_id,
      countMerge(response_count) AS response_count,
      round(avgMerge(avg_score), 2) AS avg_score
    FROM wave_question_metrics
    WHERE #{where_clauses}
    GROUP BY wave_id
    ORDER BY wave_id
    """

    with {:ok, %{rows: rows, columns: columns}} <- SurveyPulse.ClickRepo.query(sql, params) do
      raw_data =
        Enum.map(rows, fn row ->
          columns |> Enum.zip(row) |> Map.new(fn {c, v} -> {String.to_existing_atom(c), v} end)
        end)

      wave_ids = Enum.map(raw_data, & &1.wave_id)
      waves = load_wave_metadata(wave_ids)

      results =
        raw_data
        |> enrich_with_wave_metadata(waves)
        |> compute_deltas()
        |> annotate_significance()
        |> Enum.map(&struct!(SurveyPulse.Analytics.Trend, Map.put(&1, :question_id, question_id)))

      {:ok, results}
    end
  end

  defp load_wave_metadata([]), do: %{}

  defp load_wave_metadata(wave_ids) do
    import Ecto.Query

    SurveyPulse.Repo.all(
      from w in "waves",
        where: w.id in ^wave_ids,
        select: %{id: w.id, wave_number: w.wave_number, label: w.label}
    )
    |> Map.new(&{&1.id, &1})
  end

  defp enrich_with_wave_metadata(data, waves) do
    data
    |> Enum.map(fn row ->
      wave = Map.get(waves, row.wave_id, %{wave_number: 0, label: "Unknown"})

      row
      |> Map.put(:wave_number, wave.wave_number)
      |> Map.put(:wave_label, wave.label)
    end)
    |> Enum.sort_by(& &1.wave_number)
  end

  defp compute_deltas([]), do: []

  defp compute_deltas([first | rest]) do
    first_with_delta = Map.merge(first, %{delta: 0.0, pct_change: 0.0})

    {results, _} =
      Enum.reduce(rest, {[first_with_delta], first}, fn curr, {acc, prev} ->
        delta = Float.round(curr.avg_score - prev.avg_score, 2)

        pct =
          if prev.avg_score > 0,
            do: Float.round(delta / prev.avg_score * 100, 1),
            else: 0.0

        enriched = Map.merge(curr, %{delta: delta, pct_change: pct})
        {[enriched | acc], curr}
      end)

    Enum.reverse(results)
  end

  defp annotate_significance(waves) do
    Enum.map(waves, fn wave ->
      threshold = significance_threshold(wave.response_count)
      Map.put(wave, :significant?, abs(wave.delta) >= threshold)
    end)
  end

  defp significance_threshold(n) when n >= 1000, do: 0.10
  defp significance_threshold(n) when n >= 500, do: 0.15
  defp significance_threshold(n) when n >= 100, do: 0.25
  defp significance_threshold(_), do: 0.50

  defp build_filters(survey_id, question_id, filters) do
    base_clauses = "survey_id = {survey_id:UUID} AND question_id = {question_id:UUID}"
    base_params = %{"survey_id" => survey_id, "question_id" => question_id}

    Enum.reduce(filters, {base_clauses, base_params}, fn
      {:age_group, v}, {c, p} when v != "all" ->
        {c <> " AND age_group = {age_group:String}", Map.put(p, "age_group", v)}

      {:gender, v}, {c, p} when v != "all" ->
        {c <> " AND gender = {gender:String}", Map.put(p, "gender", v)}

      {:region, v}, {c, p} when v != "all" ->
        {c <> " AND region = {region:String}", Map.put(p, "region", v)}

      _, acc ->
        acc
    end)
  end
end
