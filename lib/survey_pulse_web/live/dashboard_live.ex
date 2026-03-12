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

    {:ok,
     assign(socket,
       page_title: "SurveyPulse",
       surveys: surveys,
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
              <p class="text-sm text-gray-500 mt-0.5">Consumer insights dashboard</p>
            </div>
            <div class="flex items-center gap-1.5 text-xs text-gray-400">
              <span class="relative flex h-2 w-2">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
                </span>
                <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              Live
            </div>
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
      <div class="bg-white rounded-xl border border-gray-200 p-6 shadow-sm hover:shadow-md hover:border-gray-300 transition-all">
        <div class="flex items-center justify-between mb-4">
          <span class={[
            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
            category_color(@survey.category)
          ]}>
            {format_category(@survey.category)}
          </span>
          <span class="text-xs text-gray-400">{@survey.wave_count} waves</span>
        </div>

        <h2 class="text-lg font-semibold text-gray-900 group-hover:text-indigo-600 transition-colors mb-1">
          {@survey.name}
        </h2>
        <p class="text-sm text-gray-500 line-clamp-2 mb-5">{@survey.description}</p>

        <div class="grid grid-cols-3 gap-4 pt-4 border-t border-gray-100">
          <div>
            <p class="text-xs text-gray-400 uppercase tracking-wide">Responses</p>
            <p class="text-lg font-semibold text-gray-900 mt-0.5">
              {format_number(Map.get(@metrics, :total_responses, 0))}
            </p>
            <p class="text-xs text-gray-400 mt-0.5">across {@survey.wave_count} waves</p>
          </div>
          <div>
            <p class="text-xs text-gray-400 uppercase tracking-wide">Latest Wave</p>
            <p class="text-lg font-semibold text-gray-900 mt-0.5">
              {Map.get(@metrics, :latest_wave_label, "—")}
            </p>
            <p class="text-xs text-gray-400 mt-0.5">
              {format_number(Map.get(@metrics, :latest_wave_responses, 0))} responses
            </p>
          </div>
          <div>
            <p class="text-xs text-gray-400 uppercase tracking-wide">Trend</p>
            <.trend_indicator delta={Map.get(@metrics, :latest_delta, 0)} />
            <p class="text-xs text-gray-400 mt-0.5">vs prev wave</p>
          </div>
        </div>

        <div class="pt-3 mt-4 border-t border-gray-100">
          <div
            id={"spark-#{@survey.id}"}
            phx-hook="SparkLine"
            data-scores={Jason.encode!(Map.get(@metrics, :wave_scores, []))}
            class="h-10"
          />
        </div>
      </div>
    </.link>
    """
  end

  defp trend_indicator(assigns) do
    ~H"""
    <p class={[
      "text-lg font-semibold mt-0.5",
      delta_color(@delta)
    ]}>
      {format_trend(@delta)}
    </p>
    """
  end

  defp delta_color(delta) when delta > 0, do: "text-emerald-600"
  defp delta_color(delta) when delta < 0, do: "text-red-600"
  defp delta_color(_), do: "text-gray-400"

  defp format_trend(delta) when is_float(delta) and delta > 0, do: "+#{Float.round(delta, 2)}"
  defp format_trend(delta) when is_float(delta) and delta < 0, do: "#{Float.round(delta, 2)}"
  defp format_trend(_), do: "—"

  defp category_color(:brand_health), do: "bg-blue-100 text-blue-700"
  defp category_color(:ad_testing), do: "bg-purple-100 text-purple-700"
  defp category_color(:concept_testing), do: "bg-amber-100 text-amber-700"
  defp category_color(:product_testing), do: "bg-green-100 text-green-700"
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

  defp load_survey_metrics(surveys) do
    Map.new(surveys, fn survey ->
      {survey.id, compute_survey_topline(survey.id)}
    end)
  end

  defp compute_survey_topline(survey_id) do
    wave_sql = """
    SELECT
      wave_id,
      round(avgMerge(avg_score), 2) AS avg_score,
      countMerge(response_count) AS response_count
    FROM wave_question_metrics
    WHERE survey_id = {survey_id:UUID}
    GROUP BY wave_id
    ORDER BY wave_id
    """

    case SurveyPulse.ClickRepo.query(wave_sql, %{"survey_id" => survey_id}) do
      {:ok, %{rows: rows}} when rows != [] ->
        scores = Enum.map(rows, fn [_wid, avg, _cnt] -> avg end)
        counts = Enum.map(rows, fn [_wid, _avg, cnt] -> cnt end)
        total = Enum.sum(counts)
        latest_count = List.last(counts) || 0
        latest_wave = load_latest_wave(survey_id)

        delta =
          if length(scores) >= 2 do
            [second_last, last] = Enum.take(scores, -2)
            Float.round((last || 0) - (second_last || 0), 4)
          else
            0.0
          end

        %{
          total_responses: total,
          latest_wave_label: (latest_wave && latest_wave.label) || "—",
          latest_wave_responses: latest_count,
          latest_delta: delta,
          wave_scores: scores
        }

      _ ->
        %{
          total_responses: 0,
          latest_wave_label: "—",
          latest_wave_responses: 0,
          latest_delta: 0.0,
          wave_scores: []
        }
    end
  end

  defp load_latest_wave(survey_id) do
    SurveyPulse.Repo.one(
      from(w in "waves",
        where: w.survey_id == type(^survey_id, Ecto.UUID),
        order_by: [desc: w.wave_number],
        limit: 1,
        select: %{label: w.label}
      )
    )
  end
end
