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
        "bg-white rounded-xl border border-gray-200 p-6 shadow-sm hover:shadow-md hover:border-gray-300 transition-all",
        card_accent(@metrics)
      ]}>
        <div class="flex items-center justify-between mb-4">
          <span class={[
            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
            category_color(@survey.category)
          ]}>
            {format_category(@survey.category)}
          </span>
          <span class="text-xs text-gray-400">{@survey.wave_count} rounds</span>
        </div>

        <h2 class="text-lg font-semibold text-gray-900 group-hover:text-indigo-600 transition-colors mb-1">
          {@survey.name}
        </h2>
        <p class="text-sm text-gray-500 line-clamp-2 mb-4">{@survey.description}</p>

        <div class="pt-4 border-t border-gray-100">
          <div class="flex items-center gap-2 mb-3">
            <span class={[
              "inline-flex w-2 h-2 rounded-full shrink-0",
              insight_dot_color(@metrics)
            ]} />
            <p class="text-sm font-medium text-gray-700">
              {topline_insight(@metrics)}
            </p>
          </div>
          <div class="flex items-center justify-between text-xs text-gray-400">
            <span>
              {format_number(Map.get(@metrics, :total_respondents, 0))} respondents · {@survey.wave_count} rounds
            </span>
            <span>Latest: {Map.get(@metrics, :latest_wave_label, "—")}</span>
          </div>
        </div>

        <div class="pt-3 mt-3 border-t border-gray-100">
          <p class="text-[10px] text-gray-400 uppercase tracking-wide mb-1">
            {Map.get(@metrics, :sparkline_question_code, "")} trend across rounds
          </p>
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

  defp topline_insight(metrics) do
    delta = Map.get(metrics, :latest_delta, 0.0)
    code = Map.get(metrics, :sparkline_question_code, "")

    cond do
      delta > 0.3 ->
        "#{code} trending up — improved #{format_delta(delta)} pts last round"

      delta < -0.3 ->
        "#{code} needs attention — dropped #{format_delta(abs(delta))} pts last round"

      true ->
        "#{code} holding steady across recent rounds"
    end
  end

  defp insight_dot_color(metrics) do
    delta = Map.get(metrics, :latest_delta, 0.0)

    cond do
      delta > 0.3 -> "bg-emerald-500"
      delta < -0.3 -> "bg-red-500"
      true -> "bg-gray-400"
    end
  end

  defp card_accent(metrics) do
    delta = Map.get(metrics, :latest_delta, 0.0)

    cond do
      delta > 0.3 -> "border-l-4 border-l-emerald-400"
      delta < -0.3 -> "border-l-4 border-l-red-400"
      true -> ""
    end
  end

  defp format_delta(delta) when is_float(delta) and delta > 0, do: "+#{Float.round(delta, 2)}"
  defp format_delta(delta) when is_float(delta) and delta < 0, do: "#{Float.round(delta, 2)}"
  defp format_delta(delta) when is_float(delta), do: "#{Float.round(delta, 2)}"
  defp format_delta(_), do: "—"

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
      wave_scores: [],
      sparkline_question_code: nil
    }
  end

  defp load_waves_ordered(survey_id) do
    SurveyPulse.Repo.all(
      from(w in "waves",
        where: w.survey_id == type(^survey_id, Ecto.UUID),
        order_by: [asc: w.wave_number],
        select: %{id: w.id, wave_number: w.wave_number, label: w.label}
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
        select: %{id: q.id, code: q.code}
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
          {wid, %{avg: avg, count: cnt}}
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
