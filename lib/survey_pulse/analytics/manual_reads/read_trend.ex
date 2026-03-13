defmodule SurveyPulse.Analytics.ManualReads.ReadTrend do
  @moduledoc false
  use Ash.Resource.ManualRead

  import Ecto.Query

  @impl true
  def read(query, _data_layer_query, _opts, _context) do
    survey_id = query.arguments.survey_id
    question_id = query.arguments.question_id
    filters = Map.get(query.arguments, :filters, %{})

    question_meta = load_question_meta(question_id)

    if question_meta && question_meta.question_type == :nps do
      read_nps(survey_id, question_id, filters)
    else
      read_scaled(survey_id, question_id, filters)
    end
  end

  defp read_scaled(survey_id, question_id, filters) do
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
      variance_map = load_variance(survey_id, question_id, filters)

      results =
        raw_data
        |> enrich_with_wave_metadata(waves)
        |> enrich_with_distribution(distribution)
        |> compute_deltas()
        |> annotate_significance(variance_map)
        |> Enum.map(&struct!(SurveyPulse.Analytics.Trend, Map.put(&1, :question_id, question_id)))

      {:ok, results}
    end
  end

  defp read_nps(survey_id, question_id, filters) do
    nps_data = load_nps_scores(survey_id, question_id, filters)

    wave_ids = Map.keys(nps_data)
    waves = load_wave_metadata(wave_ids)

    results =
      nps_data
      |> Enum.map(fn {wave_id, data} -> Map.put(data, :wave_id, wave_id) end)
      |> enrich_with_wave_metadata(waves)
      |> compute_deltas()
      |> annotate_significance(load_variance(survey_id, question_id, filters))
      |> Enum.map(&struct!(SurveyPulse.Analytics.Trend, Map.put(&1, :question_id, question_id)))

    {:ok, results}
  end

  defp load_nps_scores(survey_id, question_id, filters) do
    {where_clauses, params} = build_filters(survey_id, question_id, filters)

    sql = """
    SELECT
      wave_id,
      round(countIf(score >= 9) / count(*) * 100, 1) AS promoter_pct,
      round(countIf(score <= 6) / count(*) * 100, 1) AS detractor_pct,
      count(*) AS n
    FROM responses
    WHERE #{where_clauses}
    GROUP BY wave_id
    ORDER BY wave_id
    """

    case SurveyPulse.ClickRepo.query(sql, params) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [wid, promo, detract, n] ->
          {Ecto.UUID.cast!(wid), %{
            avg_score: Float.round(promo - detract, 1),
            top2_box: promo,
            bot2_box: detract,
            response_count: n
          }}
        end)
      _ ->
        %{}
    end
  rescue
    _ -> %{}
  end

  defp row_to_map(columns, row) do
    columns
    |> Enum.zip(row)
    |> Map.new(fn {c, v} -> {String.to_existing_atom(c), v} end)
    |> normalize_uuids([:wave_id])
  end

  defp normalize_uuids(map, keys) do
    Enum.reduce(keys, map, fn key, acc ->
      case Map.get(acc, key) do
        val when is_binary(val) and byte_size(val) == 16 -> Map.put(acc, key, Ecto.UUID.cast!(val))
        _ -> acc
      end
    end)
  end

  defp load_wave_metadata([]), do: %{}

  defp load_wave_metadata(wave_ids) do
    cast_ids = Enum.map(wave_ids, &Ecto.UUID.cast!/1)

    SurveyPulse.Repo.all(
      from(w in "waves",
        where: w.id in type(^cast_ids, {:array, Ecto.UUID}),
        select: %{id: type(w.id, Ecto.UUID), wave_number: w.wave_number, label: w.label}
      )
    )
    |> Map.new(&{&1.id, &1})
  end

  defp load_distribution(survey_id, question_id, filters) do
    question_meta = load_question_meta(question_id)
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
          {Ecto.UUID.cast!(wid), %{top2_box: Float.round(t2b * 100, 1), bot2_box: Float.round(b2b * 100, 1)}}
        end)

      _ ->
        %{}
    end
  rescue
    _ -> %{}
  end

  defp load_question_meta(question_id) do
    SurveyPulse.Repo.one(
      from(q in "questions",
        where: q.id == type(^question_id, Ecto.UUID),
        select: %{
          scale_min: q.scale_min,
          scale_max: q.scale_max,
          question_type: type(q.question_type, :string)
        }
      )
    )
    |> case do
      nil -> nil
      meta -> %{meta | question_type: String.to_existing_atom(meta.question_type)}
    end
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

  defp load_variance(survey_id, question_id, filters) do
    {where_clauses, params} = build_filters(survey_id, question_id, filters)

    sql = """
    SELECT
      wave_id,
      varPop(score) AS variance,
      count(*) AS n
    FROM responses
    WHERE #{where_clauses}
    GROUP BY wave_id
    """

    case SurveyPulse.ClickRepo.query(sql, params) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [wid, var, n] ->
          {Ecto.UUID.cast!(wid), %{variance: var, n: n}}
        end)
      _ ->
        %{}
    end
  rescue
    _ -> %{}
  end

  defp annotate_significance([], _variance_map), do: []

  defp annotate_significance([first | rest], variance_map) do
    first_annotated = Map.put(first, :significant?, false)

    {results, _} =
      Enum.reduce(rest, {[first_annotated], first}, fn curr, {acc, prev} ->
        significant = z_test_significant?(prev, curr, variance_map)
        {[Map.put(curr, :significant?, significant) | acc], curr}
      end)

    Enum.reverse(results)
  end

  defp z_test_significant?(prev, curr, variance_map) do
    stats_prev = Map.get(variance_map, prev.wave_id, %{variance: 1.0, n: 1})
    stats_curr = Map.get(variance_map, curr.wave_id, %{variance: 1.0, n: 1})

    n1 = max(stats_prev.n, 1)
    n2 = max(stats_curr.n, 1)

    se = :math.sqrt(stats_prev.variance / n1 + stats_curr.variance / n2)

    if se > 0 do
      z = abs(curr.avg_score - prev.avg_score) / se
      z > 1.96
    else
      false
    end
  end

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
