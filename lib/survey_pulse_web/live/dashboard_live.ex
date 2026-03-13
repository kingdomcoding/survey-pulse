defmodule SurveyPulseWeb.DashboardLive do
  use SurveyPulseWeb, :live_view

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SurveyPulse.PubSub, "analytics:updates")
    end

    surveys = SurveyPulse.Surveys.list_surveys!(load: [:wave_count, :latest_wave_number])
    survey_metrics = load_survey_metrics(surveys)

    sorted_surveys =
      Enum.sort_by(surveys, fn s ->
        delta = survey_metrics |> Map.get(s.id, %{}) |> Map.get(:latest_delta, 0.0)
        -abs(delta)
      end)

    {:ok,
     assign(socket,
       page_title: "SurveyPulse",
       surveys: sorted_surveys,
       survey_metrics: survey_metrics
     )}
  end

  @impl true
  def handle_info({:responses_ingested, _count}, socket) do
    survey_metrics = load_survey_metrics(socket.assigns.surveys)
    {:noreply, assign(socket, survey_metrics: survey_metrics)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="bg-white border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-6 py-5">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-semibold text-gray-900">SurveyPulse</h1>
              <p class="text-sm text-gray-500 mt-0.5">Track how consumer perceptions change across survey rounds</p>
            </div>
            <span class="text-xs text-gray-400">
              {length(@surveys)} surveys · {total_respondents(@survey_metrics)} respondents
            </span>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-6 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
          <.survey_card
            :for={survey <- @surveys}
            survey={survey}
            metrics={Map.get(@survey_metrics, survey.id, %{})}
          />
        </div>
      </main>
    </div>
    """
  end

  defp survey_card(assigns) do
    ~H"""
    <.link navigate={~p"/surveys/#{@survey.id}"} class="group block">
      <div class={[
        "bg-white rounded-xl border border-gray-200 p-5 shadow-sm hover:shadow-md hover:border-gray-300 transition-all"
      ]}>
        <div class="flex items-center justify-between mb-3">
          <span class={[
            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
            category_color(@survey.category)
          ]}>
            {format_category(@survey.category)}
          </span>
          <span class="text-xs text-gray-400">{@survey.wave_count} rounds</span>
        </div>

        <h2 class="text-sm font-semibold text-gray-900 group-hover:text-indigo-600 transition-colors mb-3">
          {@survey.name}
        </h2>

        <div class="flex items-baseline gap-2 mb-1">
          <span class="text-2xl font-bold text-gray-900">{format_score(@metrics)}</span>
          <span class={["text-sm font-medium", insight_color(@metrics)]}>
            {format_delta_short(@metrics)}
          </span>
          <span class={["text-xs", insight_color(@metrics)]}>
            {short_insight(@metrics)}
          </span>
        </div>

        <div
          id={"spark-#{@survey.id}"}
          phx-hook="SparkLine"
          data-scores={Jason.encode!(Map.get(@metrics, :wave_scores, []))}
          data-color={sparkline_color(@survey.category)}
          class="h-16 mb-3"
        />

        <div class="flex items-center justify-between text-xs text-gray-400">
          <span>{format_number(Map.get(@metrics, :total_respondents, 0))} respondents</span>
          <span>{Map.get(@metrics, :latest_wave_label, "—")}</span>
        </div>
      </div>
    </.link>
    """
  end

  defp format_score(metrics) do
    score = Map.get(metrics, :latest_score, 0.0)
    if score == 0.0, do: "—", else: "#{Float.round(score, 1)}"
  end

  defp format_delta_short(metrics) do
    delta = Map.get(metrics, :latest_delta, 0.0)

    cond do
      delta > 0.2 -> "+#{Float.round(delta, 2)}"
      delta < -0.2 -> "#{Float.round(delta, 2)}"
      true -> "±0"
    end
  end

  defp short_insight(metrics) do
    delta = Map.get(metrics, :latest_delta, 0.0)

    cond do
      delta > 0.2 -> "Trending up"
      delta < -0.2 -> "Needs attention"
      true -> "Holding steady"
    end
  end

  defp insight_color(metrics) do
    delta = Map.get(metrics, :latest_delta, 0.0)

    cond do
      delta > 0.2 -> "text-emerald-600"
      delta < -0.2 -> "text-red-600"
      true -> "text-gray-500"
    end
  end

  defp sparkline_color(:brand_health), do: "#3b82f6"
  defp sparkline_color(:ad_testing), do: "#8b5cf6"
  defp sparkline_color(:concept_testing), do: "#f59e0b"
  defp sparkline_color(:product_testing), do: "#06b6d4"
  defp sparkline_color(_), do: "#818cf8"

  defp category_color(:brand_health), do: "bg-blue-100 text-blue-700"
  defp category_color(:ad_testing), do: "bg-purple-100 text-purple-700"
  defp category_color(:concept_testing), do: "bg-amber-100 text-amber-700"
  defp category_color(:product_testing), do: "bg-cyan-100 text-cyan-700"
  defp category_color(_), do: "bg-gray-100 text-gray-700"

  defp format_category(:brand_health), do: "Brand Health"
  defp format_category(:ad_testing), do: "Ad Testing"
  defp format_category(:concept_testing), do: "Concept Test"
  defp format_category(:product_testing), do: "Product Test"
  defp format_category(_), do: "Survey"

  defp format_number(n) when is_number(n) and n >= 1_000_000,
    do: "#{Float.round(n / 1_000_000, 1)}M"

  defp format_number(n) when is_number(n) and n >= 1_000,
    do: "#{Float.round(n / 1_000, 1)}K"

  defp format_number(n), do: "#{n}"

  defp total_respondents(survey_metrics) do
    survey_metrics
    |> Map.values()
    |> Enum.map(&Map.get(&1, :total_respondents, 0))
    |> Enum.sum()
    |> format_number()
  end

  defp load_survey_metrics(surveys) do
    Map.new(surveys, fn survey ->
      {survey.id, compute_survey_topline(survey.id)}
    end)
  end

  defp compute_survey_topline(survey_id) do
    waves = load_waves_ordered(survey_id)
    first_question = load_first_question(survey_id)

    if waves == [] or first_question == nil do
      empty_topline()
    else
      wave_id_order = Enum.map(waves, & &1.id)
      scores_by_wave = load_question_scores(survey_id, first_question.id)
      respondent_count = load_respondent_count(survey_id)

      ordered = Enum.map(wave_id_order, &Map.get(scores_by_wave, &1, %{avg: 0.0, count: 0}))
      score_values = Enum.map(ordered, & &1.avg)
      latest_wave = List.last(waves)
      latest_scores = List.last(ordered) || %{count: 0}

      delta =
        if length(score_values) >= 2 do
          [second_last, last] = Enum.take(score_values, -2)
          Float.round(last - second_last, 4)
        else
          0.0
        end

      %{
        total_respondents: respondent_count,
        latest_wave_label: latest_wave.label,
        latest_wave_responses: Map.get(latest_scores, :count, 0),
        latest_delta: delta,
        latest_score: List.last(score_values) || 0.0,
        wave_scores: score_values,
        sparkline_question_code: first_question.code
      }
    end
  end

  defp empty_topline do
    %{
      total_respondents: 0,
      latest_wave_label: "—",
      latest_wave_responses: 0,
      latest_delta: 0.0,
      latest_score: 0.0,
      wave_scores: [],
      sparkline_question_code: nil
    }
  end

  defp load_waves_ordered(survey_id) do
    SurveyPulse.Repo.all(
      from(w in "waves",
        where: w.survey_id == type(^survey_id, Ecto.UUID),
        order_by: [asc: w.wave_number],
        select: %{id: type(w.id, Ecto.UUID), wave_number: w.wave_number, label: w.label}
      )
    )
  end

  defp load_first_question(survey_id) do
    SurveyPulse.Repo.one(
      from(q in "questions",
        where: q.survey_id == type(^survey_id, Ecto.UUID),
        where: q.question_type != "nps",
        order_by: [asc: q.inserted_at],
        limit: 1,
        select: %{id: type(q.id, Ecto.UUID), code: q.code}
      )
    )
  end

  defp load_question_scores(survey_id, question_id) do
    sql = """
    SELECT
      wave_id,
      round(avgMerge(avg_score), 2) AS avg_score,
      countMerge(response_count) AS response_count
    FROM wave_question_metrics
    WHERE survey_id = {survey_id:UUID}
      AND question_id = {question_id:UUID}
    GROUP BY wave_id
    """

    case SurveyPulse.ClickRepo.query(sql, %{
      "survey_id" => survey_id,
      "question_id" => question_id
    }) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [wid, avg, cnt] ->
          {Ecto.UUID.cast!(wid), %{avg: avg, count: cnt}}
        end)
      _ ->
        %{}
    end
  end

  defp load_respondent_count(survey_id) do
    sql = """
    SELECT count(DISTINCT respondent_id)
    FROM responses
    WHERE survey_id = {survey_id:UUID}
    """

    case SurveyPulse.ClickRepo.query(sql, %{"survey_id" => survey_id}) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end
end
