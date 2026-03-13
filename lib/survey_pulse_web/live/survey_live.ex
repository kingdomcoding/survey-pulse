defmodule SurveyPulseWeb.SurveyLive do
  use SurveyPulseWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SurveyPulse.PubSub, "analytics:updates")
    end

    survey = SurveyPulse.Surveys.get_survey!(id, load: [:questions, :waves])

    {:ok,
     assign(socket,
       page_title: survey.name,
       survey: survey,
       available_filters: load_available_filters(survey.id),
       selected_question_id: nil,
       filters: %{age_group: "all", gender: "all", region: "all"},
       trend_data: []
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    survey = socket.assigns.survey
    first_question = List.first(survey.questions)

    question_id = params["question"] || (first_question && first_question.id)

    filters = %{
      age_group: params["age_group"] || "all",
      gender: params["gender"] || "all",
      region: params["region"] || "all"
    }

    trend_data = load_trend_data(survey.id, question_id, filters)

    {:noreply,
     assign(socket,
       selected_question_id: question_id,
       filters: filters,
       trend_data: trend_data
     )}
  end

  @impl true
  def handle_event("select_question", %{"question_id" => question_id}, socket) do
    query_params =
      filter_query_params(socket.assigns.filters)
      |> Map.put("question", question_id)

    {:noreply, push_patch(socket, to: ~p"/surveys/#{socket.assigns.survey.id}?#{query_params}")}
  end

  @impl true
  def handle_event("filter", params, socket) do
    query_params = %{
      "age_group" => params["age_group"] || "all",
      "gender" => params["gender"] || "all",
      "region" => params["region"] || "all",
      "question" => socket.assigns.selected_question_id
    }

    {:noreply, push_patch(socket, to: ~p"/surveys/#{socket.assigns.survey.id}?#{query_params}")}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    query_params = %{"question" => socket.assigns.selected_question_id}
    {:noreply, push_patch(socket, to: ~p"/surveys/#{socket.assigns.survey.id}?#{query_params}")}
  end

  @impl true
  def handle_info({:responses_ingested, _count}, socket) do
    trend_data =
      load_trend_data(
        socket.assigns.survey.id,
        socket.assigns.selected_question_id,
        socket.assigns.filters
      )

    {:noreply, assign(socket, trend_data: trend_data)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="bg-white border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-6 py-5">
          <div class="flex items-center gap-3 mb-2">
            <.link navigate={~p"/"} class="text-gray-400 hover:text-gray-600 transition-colors">
              <.icon name="hero-arrow-left" class="h-5 w-5" />
            </.link>
            <span class={[
              "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
              category_color(@survey.category)
            ]}>
              {format_category(@survey.category)}
            </span>
          </div>
          <h1 class="text-2xl font-semibold text-gray-900">{@survey.name}</h1>
          <p class="text-sm text-gray-500 mt-1">{@survey.description}</p>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-6 py-8 space-y-8">
        <.filter_bar filters={@filters} available_filters={@available_filters} />
        <.active_filters filters={@filters} />
        <.sample_warning total={total_filtered_responses(@trend_data)} />

        <div class="flex gap-2 overflow-x-auto pb-1">
          <button
            :for={q <- @survey.questions}
            phx-click="select_question"
            phx-value-question_id={q.id}
            class={[
              "px-4 py-2 rounded-lg text-sm font-medium transition-colors flex flex-col items-start",
              if(q.id == @selected_question_id,
                do: "bg-indigo-600 text-white shadow-sm",
                else: "bg-white text-gray-600 border border-gray-200 hover:border-gray-300"
              )
            ]}
          >
            <span class="font-semibold">{q.code}</span>
            <span class={[
              "text-xs mt-0.5 max-w-[180px] truncate",
              if(q.id == @selected_question_id, do: "text-indigo-200", else: "text-gray-400")
            ]}>
              {q.text}
            </span>
          </button>
        </div>

        <div class="bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
          <div class="flex items-start justify-between mb-6">
            <div>
              <h2 class="text-lg font-semibold text-gray-900 mb-1">Score Over Time</h2>
              <p class="text-sm text-gray-500">
                {selected_question_text(@survey.questions, @selected_question_id)}
              </p>
            </div>
            <span class={[
              "inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-medium shrink-0",
              scale_badge_color(selected_question(@survey.questions, @selected_question_id))
            ]}>
              {scale_label(selected_question(@survey.questions, @selected_question_id))}
            </span>
          </div>
          <%= if @trend_data == [] do %>
            <div class="h-80 flex items-center justify-center">
              <div class="text-center">
                <.icon name="hero-chart-bar" class="h-12 w-12 text-gray-300 mx-auto mb-3" />
                <p class="text-sm text-gray-500">No data available for this question</p>
                <p :if={any_filter_active?(@filters)} class="text-xs text-gray-400 mt-1">
                  Try adjusting your filters
                </p>
              </div>
            </div>
          <% else %>
            <div class="flex items-center gap-5 mb-4 text-xs text-gray-500">
              <div class="flex items-center gap-1.5">
                <span class="inline-block w-6 h-0.5 bg-indigo-500 rounded"></span>
                <span class="inline-flex w-2 h-2 rounded-full bg-indigo-500"></span>
                Score trend
              </div>
              <div class="flex items-center gap-1.5">
                <span class="inline-flex w-3 h-3 rounded-full bg-emerald-500 border-2 border-white shadow-sm">
                </span>
                Significant increase
              </div>
              <div class="flex items-center gap-1.5">
                <span class="inline-flex w-3 h-3 rounded-full bg-red-500 border-2 border-white shadow-sm">
                </span>
                Significant decrease
              </div>
            </div>
            <div
              id="trend-chart"
              phx-hook="TrendChart"
              data-trend={Jason.encode!(trend_data_for_chart(@trend_data))}
              data-scale-min={scale_min(@survey.questions, @selected_question_id)}
              data-scale-max={scale_max(@survey.questions, @selected_question_id)}
              data-question-type={question_type(@survey.questions, @selected_question_id)}
              class="h-80"
            />
          <% end %>
        </div>

        <div class="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">Round-by-Round Detail</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Round
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Responses
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {if question_type(@survey.questions, @selected_question_id) == :nps,
                      do: "NPS Score", else: "Avg Score"}
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {if question_type(@survey.questions, @selected_question_id) == :nps,
                      do: "Promoters", else: "Positive %"}
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {if question_type(@survey.questions, @selected_question_id) == :nps,
                      do: "Detractors", else: "Negative %"}
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Change
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-100">
                <tr :if={@trend_data == []}>
                  <td colspan="7" class="px-6 py-12 text-center text-sm text-gray-500">
                    No data available
                  </td>
                </tr>
                <tr :for={point <- @trend_data} class="hover:bg-gray-50">
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {point.wave_label}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-600 text-right">
                    {format_number(point.response_count)}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900 font-semibold text-right">
                    {point.avg_score}
                  </td>
                  <td class="px-6 py-4 text-sm text-emerald-600 font-medium text-right">
                    {point.top2_box}%
                  </td>
                  <td class="px-6 py-4 text-sm text-red-600 font-medium text-right">
                    {point.bot2_box}%
                  </td>
                  <td class={[
                    "px-6 py-4 text-sm font-medium text-right",
                    if(point.wave_number == 1, do: "text-gray-400", else: delta_color(point.delta))
                  ]}>
                    {if point.wave_number == 1, do: "—", else: format_delta(point.delta)}
                  </td>
                  <td class="px-6 py-4 text-right">
                    <span
                      :if={point.significant?}
                      class={[
                        "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                        if(point.delta > 0,
                          do: "bg-emerald-100 text-emerald-700",
                          else: "bg-red-100 text-red-700"
                        )
                      ]}
                    >
                      {if point.delta > 0, do: "Significant ↑", else: "Significant ↓"}
                    </span>
                    <span
                      :if={!point.significant? and point.wave_number == 1}
                      class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-500"
                    >
                      First round
                    </span>
                    <span
                      :if={!point.significant? and point.wave_number != 1}
                      class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-500"
                    >
                      Stable
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp filter_bar(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-4">
      <div>
        <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">
          Age Group
        </label>
        <select
          phx-change="filter"
          name="age_group"
          class="rounded-lg border-gray-300 text-sm focus:ring-indigo-500 focus:border-indigo-500"
        >
          <option value="all" selected={@filters.age_group == "all"}>All Ages</option>
          <option
            :for={ag <- @available_filters.age_groups}
            value={ag}
            selected={@filters.age_group == ag}
          >
            {ag}
          </option>
        </select>
      </div>
      <div>
        <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">
          Gender
        </label>
        <select
          phx-change="filter"
          name="gender"
          class="rounded-lg border-gray-300 text-sm focus:ring-indigo-500 focus:border-indigo-500"
        >
          <option value="all" selected={@filters.gender == "all"}>All Genders</option>
          <option
            :for={g <- @available_filters.genders}
            value={g}
            selected={@filters.gender == g}
          >
            {format_gender(g)}
          </option>
        </select>
      </div>
      <div>
        <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">
          Region
        </label>
        <select
          phx-change="filter"
          name="region"
          class="rounded-lg border-gray-300 text-sm focus:ring-indigo-500 focus:border-indigo-500"
        >
          <option value="all" selected={@filters.region == "all"}>All Regions</option>
          <option
            :for={r <- @available_filters.regions}
            value={r}
            selected={@filters.region == r}
          >
            {format_region(r)}
          </option>
        </select>
      </div>
    </div>
    """
  end

  defp active_filters(assigns) do
    ~H"""
    <div :if={any_filter_active?(@filters)} class="flex items-center gap-2 flex-wrap">
      <span class="text-xs font-medium text-gray-500 uppercase tracking-wide">Filtered by:</span>
      <span
        :if={@filters.age_group != "all"}
        class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-indigo-100 text-indigo-700"
      >
        Age: {@filters.age_group}
      </span>
      <span
        :if={@filters.gender != "all"}
        class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-indigo-100 text-indigo-700"
      >
        Gender: {format_gender(@filters.gender)}
      </span>
      <span
        :if={@filters.region != "all"}
        class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-indigo-100 text-indigo-700"
      >
        Region: {format_region(@filters.region)}
      </span>
      <button phx-click="clear_filters" class="text-xs text-gray-400 hover:text-gray-600 underline">
        Clear all
      </button>
    </div>
    """
  end

  defp sample_warning(assigns) do
    ~H"""
    <div
      :if={@total < 100 and @total > 0}
      class="flex items-center gap-2 px-4 py-2.5 bg-amber-50 border border-amber-200 rounded-lg text-sm text-amber-800"
    >
      <.icon name="hero-exclamation-triangle" class="h-4 w-4 text-amber-500 shrink-0" />
      <span>Small sample size ({@total} responses). Results may not be statistically reliable.</span>
    </div>
    """
  end

  defp any_filter_active?(filters) do
    filters.age_group != "all" or filters.gender != "all" or filters.region != "all"
  end

  defp format_gender("non_binary"), do: "Non-Binary"
  defp format_gender(g), do: String.capitalize(g)

  defp format_region("north_america"), do: "North America"
  defp format_region("asia_pacific"), do: "Asia Pacific"
  defp format_region("latin_america"), do: "Latin America"
  defp format_region(r), do: String.capitalize(r)

  defp total_filtered_responses(trend_data) do
    trend_data |> Enum.map(& &1.response_count) |> Enum.sum()
  end

  defp load_trend_data(_survey_id, nil, _filters), do: []

  defp load_trend_data(survey_id, question_id, filters) do
    if filters == %{age_group: "all", gender: "all", region: "all"} do
      SurveyPulse.Analytics.longitudinal_trend!(survey_id, question_id)
    else
      SurveyPulse.Analytics.longitudinal_trend_filtered!(survey_id, question_id, filters)
    end
  end

  defp trend_data_for_chart(trend_data) do
    Enum.map(trend_data, fn point ->
      %{
        wave_label: point.wave_label,
        wave_number: point.wave_number,
        avg_score: point.avg_score,
        delta: point.delta,
        response_count: point.response_count,
        significant: point.significant?,
        top2_box: point.top2_box,
        bot2_box: point.bot2_box
      }
    end)
  end

  defp selected_question(questions, selected_id) do
    Enum.find(questions, &(&1.id == selected_id))
  end

  defp selected_question_text(questions, selected_id) do
    case selected_question(questions, selected_id) do
      nil -> ""
      q -> q.text
    end
  end

  defp scale_label(nil), do: ""
  defp scale_label(%{question_type: :nps}), do: "NPS · −100 to +100"
  defp scale_label(%{question_type: :likert, scale_min: mn, scale_max: mx}), do: "Likert · #{mn}–#{mx}"
  defp scale_label(%{scale_min: mn, scale_max: mx}), do: "Scale · #{mn}–#{mx}"

  defp scale_badge_color(nil), do: "bg-gray-100 text-gray-500"
  defp scale_badge_color(%{question_type: :nps}), do: "bg-violet-100 text-violet-700"
  defp scale_badge_color(_), do: "bg-blue-100 text-blue-700"

  defp question_type(questions, id) do
    case selected_question(questions, id) do
      nil -> :likert
      q -> q.question_type
    end
  end

  defp scale_min(questions, id) do
    case selected_question(questions, id) do
      nil -> 0
      %{question_type: :nps} -> -100
      q -> q.scale_min
    end
  end

  defp scale_max(questions, id) do
    case selected_question(questions, id) do
      nil -> 10
      %{question_type: :nps} -> 100
      q -> q.scale_max
    end
  end

  defp delta_color(delta) when is_float(delta) and delta > 0, do: "text-emerald-600"
  defp delta_color(delta) when is_float(delta) and delta < 0, do: "text-red-600"
  defp delta_color(_), do: "text-gray-400"

  defp format_delta(delta) when is_float(delta) and delta > 0, do: "+#{Float.round(delta, 2)}"
  defp format_delta(delta) when is_float(delta) and delta < 0, do: "#{Float.round(delta, 2)}"
  defp format_delta(_), do: "—"

  defp format_number(n) when is_integer(n) and n >= 1_000,
    do: "#{Float.round(n / 1_000, 1)}K"

  defp format_number(n), do: "#{n}"

  defp category_color(:brand_health), do: "bg-blue-100 text-blue-700"
  defp category_color(:ad_testing), do: "bg-purple-100 text-purple-700"
  defp category_color(:concept_testing), do: "bg-amber-100 text-amber-700"
  defp category_color(:product_testing), do: "bg-green-100 text-green-700"
  defp category_color(_), do: "bg-gray-100 text-gray-700"

  defp load_available_filters(survey_id) do
    sql = """
    SELECT
      groupUniqArray(age_group) AS age_groups,
      groupUniqArray(gender) AS genders,
      groupUniqArray(region) AS regions
    FROM responses
    WHERE survey_id = {survey_id:UUID}
    """

    case SurveyPulse.ClickRepo.query(sql, %{"survey_id" => survey_id}) do
      {:ok, %{rows: [[age_groups, genders, regions]]}} ->
        %{
          age_groups: Enum.sort(age_groups),
          genders: Enum.sort(genders),
          regions: Enum.sort(regions)
        }

      _ ->
        %{age_groups: [], genders: [], regions: []}
    end
  rescue
    _ -> %{age_groups: [], genders: [], regions: []}
  end

  defp filter_query_params(filters) do
    %{
      "age_group" => filters.age_group,
      "gender" => filters.gender,
      "region" => filters.region
    }
  end

  defp format_category(:brand_health), do: "Brand Health"
  defp format_category(:ad_testing), do: "Ad Testing"
  defp format_category(:concept_testing), do: "Concept Test"
  defp format_category(:product_testing), do: "Product Test"
  defp format_category(_), do: "Survey"
end
