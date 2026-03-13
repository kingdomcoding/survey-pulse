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
       trend_data: [],
       insight: nil,
       breakdown_dimension: :age_group,
       breakdown_data: [],
       compare_question_id: nil,
       compare_trend_data: [],
       generating: false,
       sample_pattern: "steady_growth",
       simulating: SurveyPulse.Ingestion.Simulator.running?(id)
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
    question = selected_question(survey.questions, question_id)
    insight = compute_insight(trend_data, question)

    latest_wave = List.last(survey.waves)

    breakdown_data =
      if latest_wave && question_id do
        SurveyPulse.Analytics.demographic_breakdown!(
          survey.id,
          question_id,
          latest_wave.id,
          socket.assigns.breakdown_dimension
        )
      else
        []
      end

    {:noreply,
     assign(socket,
       selected_question_id: question_id,
       filters: filters,
       trend_data: trend_data,
       insight: insight,
       breakdown_data: breakdown_data,
       compare_question_id: nil,
       compare_trend_data: []
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
  def handle_event("generate_sample_data", %{"pattern" => pattern}, socket) do
    send(self(), {:do_generate, pattern})
    {:noreply, assign(socket, generating: true, sample_pattern: pattern)}
  end

  @impl true
  def handle_event("toggle_compare", %{"question_id" => ""}, socket) do
    {:noreply, assign(socket, compare_question_id: nil, compare_trend_data: [])}
  end

  @impl true
  def handle_event("toggle_compare", %{"question_id" => qid}, socket) do
    data = load_trend_data(socket.assigns.survey.id, qid, socket.assigns.filters)
    {:noreply, assign(socket, compare_question_id: qid, compare_trend_data: data)}
  end

  @impl true
  def handle_event("change_dimension", %{"dimension" => dim}, socket) do
    dimension = String.to_existing_atom(dim)
    latest_wave = List.last(socket.assigns.survey.waves)

    data =
      if latest_wave do
        SurveyPulse.Analytics.demographic_breakdown!(
          socket.assigns.survey.id,
          socket.assigns.selected_question_id,
          latest_wave.id,
          dimension
        )
      else
        []
      end

    {:noreply, assign(socket, breakdown_dimension: dimension, breakdown_data: data)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    query_params = %{"question" => socket.assigns.selected_question_id}
    {:noreply, push_patch(socket, to: ~p"/surveys/#{socket.assigns.survey.id}?#{query_params}")}
  end

  @impl true
  def handle_event("start_simulation", _params, socket) do
    survey = socket.assigns.survey
    latest_wave = List.last(survey.waves)

    if latest_wave do
      SurveyPulse.Ingestion.Simulator.start(
        survey_id: survey.id,
        wave_id: latest_wave.id,
        questions: survey.questions,
        wave_num: latest_wave.wave_number
      )
    end

    {:noreply, assign(socket, simulating: true)}
  end

  @impl true
  def handle_event("stop_simulation", _params, socket) do
    SurveyPulse.Ingestion.Simulator.stop(socket.assigns.survey.id)
    {:noreply, assign(socket, simulating: false)}
  end

  @impl true
  def handle_info({:do_generate, pattern}, socket) do
    survey = socket.assigns.survey
    pattern_atom = String.to_existing_atom(pattern)

    SurveyPulse.SampleData.generate!(survey.id, survey.questions,
      wave_count: 6,
      responses_per_wave: 500,
      pattern: pattern_atom
    )

    survey = SurveyPulse.Surveys.get_survey!(survey.id, load: [:questions, :waves])
    first_question = List.first(survey.questions)

    {:noreply,
     socket
     |> put_flash(:info, "Generated 6 rounds of sample data")
     |> assign(generating: false, survey: survey, available_filters: load_available_filters(survey.id))
     |> push_patch(to: ~p"/surveys/#{survey.id}?question=#{first_question && first_question.id}")}
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

      <main class="max-w-7xl mx-auto px-6 py-8 space-y-6 animate-in">
        <div :if={@survey.waves == []} class="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="px-8 pt-10 pb-6 text-center">
            <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-indigo-50 mb-4">
              <.icon name="hero-chart-bar" class="h-8 w-8 text-indigo-400" />
            </div>
            <h3 class="text-lg font-semibold text-gray-900 mb-1">Ready to see this survey in action?</h3>
            <p class="text-sm text-gray-500 max-w-sm mx-auto">
              Generate realistic sample data to explore trends, breakdowns, and round-by-round analysis.
            </p>
          </div>
          <div class="px-8 pb-8">
            <div class="grid grid-cols-3 gap-3">
              <button
                :for={{pattern, label, desc, icon} <- sample_patterns()}
                phx-click="generate_sample_data"
                phx-value-pattern={pattern}
                disabled={@generating}
                class={[
                  "relative text-left p-4 rounded-xl border-2 transition-all",
                  "hover:border-indigo-300 hover:bg-indigo-50/50",
                  "disabled:opacity-60 disabled:cursor-wait",
                  if(@generating && @sample_pattern == pattern,
                    do: "border-indigo-400 bg-indigo-50",
                    else: "border-gray-200 bg-white"
                  )
                ]}
              >
                <.icon name={icon} class="h-5 w-5 text-indigo-500 mb-2" />
                <span class="block text-sm font-medium text-gray-900">{label}</span>
                <span class="block text-xs text-gray-500 mt-0.5">{desc}</span>
                <svg :if={@generating && @sample_pattern == pattern} class="absolute top-3 right-3 animate-spin h-4 w-4 text-indigo-500" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none" />
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
              </button>
            </div>
          </div>
        </div>

        <.key_insight :if={@survey.waves != []} insight={@insight} />

        <div :if={@survey.waves != []} class="relative">
          <div class="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-gray-50 to-transparent pointer-events-none z-10" />
          <div class="flex gap-2 overflow-x-auto pb-1 scroll-smooth">
            <button
              :for={q <- @survey.questions}
              phx-click="select_question"
              phx-value-question_id={q.id}
              class={[
                "px-4 py-2.5 rounded-lg text-sm transition-colors text-left min-w-0 shrink-0",
                "phx-click-loading:opacity-70 phx-click-loading:cursor-wait",
                "focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2",
                if(q.id == @selected_question_id,
                  do: "bg-indigo-600 text-white shadow-sm",
                  else: "bg-white text-gray-600 border border-gray-200 hover:border-gray-300"
                )
              ]}
            >
              <span class="block font-medium truncate max-w-[240px]">{shorten_question(q.text)}</span>
              <span class={[
                "text-xs mt-0.5 block",
                if(q.id == @selected_question_id, do: "text-indigo-200", else: "text-gray-400")
              ]}>
                {q.code}{if q.question_type == :nps, do: " · NPS", else: " · 1–#{q.scale_max}"}
              </span>
            </button>
          </div>
        </div>

        <div :if={@survey.waves != []} class="bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
          <div class="flex items-start justify-between mb-6">
            <div>
              <h2 class="text-lg font-semibold text-gray-900 mb-1">Score Over Time</h2>
              <p class="text-sm text-gray-500">
                {selected_question_text(@survey.questions, @selected_question_id)}
              </p>
            </div>
            <div class="flex items-center gap-2">
              <form :if={comparable_questions(@survey.questions, @selected_question_id) != []} phx-change="toggle_compare">
                <select
                  name="question_id"
                  class={[
                    "text-xs rounded-lg border py-1.5 pl-2.5 pr-7 transition-colors cursor-pointer",
                    if(@compare_question_id,
                      do: "border-amber-300 bg-amber-50 text-amber-800",
                      else: "border-gray-300 text-gray-500"
                    )
                  ]}
                >
                  <option value="">Compare with…</option>
                  <option
                    :for={q <- comparable_questions(@survey.questions, @selected_question_id)}
                    value={q.id}
                    selected={@compare_question_id == q.id}
                  >
                    {q.code} — {shorten_question(q.text)}
                  </option>
                </select>
              </form>
              <span class={[
                "inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-medium shrink-0",
                scale_badge_color(selected_question(@survey.questions, @selected_question_id))
              ]}>
                {scale_label(selected_question(@survey.questions, @selected_question_id))}
              </span>
            </div>
          </div>
          <%= if @trend_data == [] do %>
            <div class="h-80 flex items-center justify-center">
              <div class="text-center">
                <.icon name={if any_filter_active?(@filters), do: "hero-funnel", else: "hero-chart-bar"} class="h-12 w-12 text-gray-300 mx-auto mb-3" />
                <p class="text-sm font-medium text-gray-900 mb-1">
                  {if any_filter_active?(@filters), do: "No results match these filters", else: "No data available for this question"}
                </p>
                <p :if={any_filter_active?(@filters)} class="text-xs text-gray-500 mb-3">
                  This combination has no responses in this question.
                </p>
                <button
                  :if={any_filter_active?(@filters)}
                  phx-click="clear_filters"
                  class="text-xs font-medium text-indigo-600 hover:text-indigo-700"
                >
                  Clear all filters
                </button>
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
              data-compare={if @compare_trend_data != [], do: Jason.encode!(trend_data_for_chart(@compare_trend_data)), else: ""}
              data-primary-label={selected_question(@survey.questions, @selected_question_id) |> then(& &1 && &1.code)}
              data-compare-label={selected_question(@survey.questions, @compare_question_id) |> then(& &1 && &1.code)}
              data-scale-min={scale_min(@survey.questions, @selected_question_id)}
              data-scale-max={scale_max(@survey.questions, @selected_question_id)}
              data-question-type={question_type(@survey.questions, @selected_question_id)}
              class="h-80 phx-change-loading:opacity-50 phx-change-loading:animate-pulse transition-opacity"
            />
          <% end %>
        </div>

        <div :if={@breakdown_data != []} class="bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
          <div class="flex items-center justify-between mb-5">
            <h2 class="text-lg font-semibold text-gray-900">Demographic Breakdown</h2>
            <div class="inline-flex rounded-lg border border-gray-200 p-0.5 bg-gray-50">
              <button
                :for={dim <- [:age_group, :gender, :region]}
                phx-click="change_dimension"
                phx-value-dimension={dim}
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-md transition-all",
                  if(@breakdown_dimension == dim,
                    do: "bg-white text-gray-900 shadow-sm",
                    else: "text-gray-500 hover:text-gray-700"
                  )
                ]}
              >
                {format_dimension(dim)}
              </button>
            </div>
          </div>
          <div
            id="breakdown-chart"
            phx-hook="BreakdownChart"
            data-breakdown={Jason.encode!(Enum.map(@breakdown_data, fn b -> %{segment: b.segment, avg_score: b.avg_score, response_count: b.response_count, top2_box: b.top2_box} end))}
            class="h-80"
          />
        </div>

        <div :if={@survey.waves != []} class="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between flex-wrap gap-3">
            <h2 class="text-lg font-semibold text-gray-900">Round-by-Round Detail</h2>
            <div class="flex items-center gap-3">
              <a
                href={~p"/surveys/#{@survey.id}/export?#{export_params(@selected_question_id, @filters)}"}
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-600 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                download
              >
                <.icon name="hero-arrow-down-tray" class="h-3.5 w-3.5" />
                CSV
              </a>
              <.filter_bar filters={@filters} available_filters={@available_filters} />
            </div>
          </div>
          <.active_filters filters={@filters} />
          <.sample_warning total={total_filtered_responses(@trend_data)} />
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50 sticky top-0 z-10">
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
                <tr
                  :for={point <- @trend_data}
                  class={[
                    "hover:bg-gray-50 transition-colors",
                    if(point == List.last(@trend_data), do: "bg-indigo-50/50", else: "")
                  ]}
                >
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {point.wave_label}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-600 text-right tabular-nums">
                    {format_number(point.response_count)}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-900 font-semibold text-right tabular-nums">
                    {point.avg_score}
                  </td>
                  <td class="px-6 py-4 text-sm text-emerald-600 font-medium text-right tabular-nums">
                    {point.top2_box}%
                  </td>
                  <td class="px-6 py-4 text-sm text-red-600 font-medium text-right tabular-nums">
                    {point.bot2_box}%
                  </td>
                  <td class={[
                    "px-6 py-4 text-sm font-medium text-right tabular-nums",
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
    <form phx-change="filter" class="flex flex-wrap items-center gap-2">
      <select
        name="age_group"
        class="rounded-lg border-gray-300 text-xs py-1.5 pl-2 pr-7 focus:ring-indigo-500 focus:border-indigo-500 phx-change-loading:opacity-60 phx-change-loading:cursor-wait"
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
      <select
        name="gender"
        class="rounded-lg border-gray-300 text-xs py-1.5 pl-2 pr-7 focus:ring-indigo-500 focus:border-indigo-500 phx-change-loading:opacity-60 phx-change-loading:cursor-wait"
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
      <select
        name="region"
        class="rounded-lg border-gray-300 text-xs py-1.5 pl-2 pr-7 focus:ring-indigo-500 focus:border-indigo-500 phx-change-loading:opacity-60 phx-change-loading:cursor-wait"
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
    </form>
    """
  end

  defp active_filters(assigns) do
    ~H"""
    <div :if={any_filter_active?(@filters)} class="flex items-center gap-2 flex-wrap px-6 py-2 bg-indigo-50 border-b border-indigo-100">
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
      class="flex items-center gap-2 px-6 py-2.5 bg-amber-50 border-b border-amber-200 text-sm text-amber-800"
    >
      <.icon name="hero-exclamation-triangle" class="h-4 w-4 text-amber-500 shrink-0" />
      <span>Small sample size ({@total} responses). Results may not be statistically reliable.</span>
    </div>
    """
  end

  defp key_insight(assigns) do
    ~H"""
    <div :if={@insight} class={[
      "flex items-start gap-3 px-5 py-4 rounded-xl border",
      insight_style(@insight.type)
    ]}>
      <.icon name={insight_icon(@insight.type)} class="h-5 w-5 mt-0.5 shrink-0" />
      <div>
        <p class="text-sm font-semibold">{@insight.headline}</p>
        <p class="text-sm mt-0.5 opacity-80">{@insight.detail}</p>
      </div>
    </div>
    """
  end

  defp insight_style(:positive), do: "bg-emerald-50 border-emerald-200 text-emerald-800"
  defp insight_style(:negative), do: "bg-red-50 border-red-200 text-red-800"
  defp insight_style(_), do: "bg-gray-50 border-gray-200 text-gray-700"

  defp insight_icon(:positive), do: "hero-arrow-trending-up"
  defp insight_icon(:negative), do: "hero-arrow-trending-down"
  defp insight_icon(_), do: "hero-minus"

  defp compute_insight([], _question), do: nil
  defp compute_insight(_trend_data, nil), do: nil

  defp compute_insight(trend_data, question) do
    latest = List.last(trend_data)

    cond do
      latest.wave_number == 1 ->
        %{
          type: :neutral,
          headline: "First round collected",
          detail: "#{format_number(latest.response_count)} responses recorded. Future rounds will be compared against this baseline."
        }

      latest.significant? and latest.delta > 0 ->
        %{
          type: :positive,
          headline: "#{question.text} improved significantly",
          detail: "Up #{format_delta(latest.delta)} points from the previous round (#{format_number(latest.response_count)} responses, statistically significant)."
        }

      latest.significant? and latest.delta < 0 ->
        %{
          type: :negative,
          headline: "#{question.text} declined significantly",
          detail: "Down #{format_delta(abs(latest.delta))} points from the previous round (#{format_number(latest.response_count)} responses, statistically significant)."
        }

      true ->
        %{
          type: :neutral,
          headline: "No significant change detected",
          detail: "Score moved #{format_delta(latest.delta)} points — within normal variation (#{format_number(latest.response_count)} responses)."
        }
    end
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

  defp shorten_question(text) do
    if String.length(text) > 45, do: String.slice(text, 0, 42) <> "...", else: text
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
  defp category_color(:product_testing), do: "bg-cyan-100 text-cyan-700"
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

  defp export_params(question_id, filters) do
    %{"question" => question_id}
    |> Map.merge(filter_query_params(filters))
  end

  defp filter_query_params(filters) do
    %{
      "age_group" => filters.age_group,
      "gender" => filters.gender,
      "region" => filters.region
    }
  end

  defp comparable_questions(questions, selected_id) do
    sel = selected_question(questions, selected_id)

    if sel do
      Enum.filter(questions, &(&1.id != selected_id && &1.question_type == sel.question_type))
    else
      []
    end
  end

  defp sample_patterns do
    [
      {"steady_growth", "Steady Growth", "Gradual upward trend", "hero-arrow-trending-up"},
      {"campaign_spike", "Campaign Spike", "Sharp mid-point surge", "hero-bolt"},
      {"iteration_improvement", "Iterative Improvement", "Step-by-step gains", "hero-arrow-path"}
    ]
  end

  defp format_dimension(:age_group), do: "Age"
  defp format_dimension(:gender), do: "Gender"
  defp format_dimension(:region), do: "Region"

  defp format_category(:brand_health), do: "Brand Health"
  defp format_category(:ad_testing), do: "Ad Testing"
  defp format_category(:concept_testing), do: "Concept Test"
  defp format_category(:product_testing), do: "Product Test"
  defp format_category(_), do: "Survey"
end
