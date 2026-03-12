defmodule SurveyPulse.Analytics.ManualReads.ReadTrend do
  @moduledoc false
  use Ash.Resource.ManualRead

  import Ecto.Query

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
      raw_data = Enum.map(rows, &row_to_map(columns, &1))

      wave_ids = Enum.map(raw_data, & &1.wave_id)
      waves = load_wave_metadata(wave_ids)
      distribution = load_distribution(survey_id, question_id, filters)

      results =
        raw_data
        |> enrich_with_wave_metadata(waves)
        |> enrich_with_distribution(distribution)
        |> compute_deltas()
        |> annotate_significance()
        |> Enum.map(&struct!(SurveyPulse.Analytics.Trend, Map.put(&1, :question_id, question_id)))

      {:ok, results}
    end
  end

  defp row_to_map(columns, row) do
    columns |> Enum.zip(row) |> Map.new(fn {c, v} -> {String.to_existing_atom(c), v} end)
  end

  defp load_wave_metadata([]), do: %{}

  defp load_wave_metadata(wave_ids) do
    SurveyPulse.Repo.all(
      from(w in "waves",
        where: w.id in type(^wave_ids, {:array, Ecto.UUID}),
        select: %{id: w.id, wave_number: w.wave_number, label: w.label}
      )
    )
    |> Map.new(&{&1.id, &1})
  end

  defp load_distribution(survey_id, question_id, filters) do
    question_meta = load_question_scale(question_id)
    scale_max = (question_meta && question_meta.scale_max) || 5
    scale_min = (question_meta && question_meta.scale_min) || 1

    top2_threshold = scale_max - 1
    bot2_threshold = scale_min + 1

    {where_clauses, params} = build_filters(survey_id, question_id, filters)

    params =
      Map.merge(params, %{
        "top2_threshold" => top2_threshold,
        "bot2_threshold" => bot2_threshold
      })

    sql = """
    SELECT
      wave_id,
      countIf(score >= {top2_threshold:Int32}) / count(*) AS top2_box,
      countIf(score <= {bot2_threshold:Int32}) / count(*) AS bot2_box
    FROM responses
    WHERE #{where_clauses}
    GROUP BY wave_id
    ORDER BY wave_id
    """

    case SurveyPulse.ClickRepo.query(sql, params) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [wid, t2b, b2b] ->
          {wid, %{top2_box: Float.round(t2b * 100, 1), bot2_box: Float.round(b2b * 100, 1)}}
        end)

      _ ->
        %{}
    end
  rescue
    _ -> %{}
  end

  defp load_question_scale(question_id) do
    SurveyPulse.Repo.one(
      from(q in "questions",
        where: q.id == type(^question_id, Ecto.UUID),
        select: %{scale_min: q.scale_min, scale_max: q.scale_max}
      )
    )
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

  defp enrich_with_distribution(data, distribution) do
    Enum.map(data, fn row ->
      dist = Map.get(distribution, row.wave_id, %{top2_box: 0.0, bot2_box: 0.0})
      Map.merge(row, dist)
    end)
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
