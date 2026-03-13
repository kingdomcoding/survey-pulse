defmodule SurveyPulseWeb.SurveyFormLive do
  use SurveyPulseWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "New Survey",
       name: "",
       description: "",
       category: "brand_health",
       questions: [blank_question(0)],
       errors: %{},
       question_errors: []
     )}
  end

  @impl true
  def handle_event("validate", params, socket) do
    name = params["name"] || ""
    description = params["description"] || ""
    category = params["category"] || "brand_health"

    questions =
      update_questions_from_params(socket.assigns.questions, params)

    errors = validate_fields(name)
    question_errors = validate_questions(questions)

    {:noreply,
     assign(socket,
       name: name,
       description: description,
       category: category,
       questions: questions,
       errors: errors,
       question_errors: question_errors
     )}
  end

  @impl true
  def handle_event("add_question", _params, socket) do
    next_index = length(socket.assigns.questions)
    questions = socket.assigns.questions ++ [blank_question(next_index)]
    {:noreply, assign(socket, questions: questions)}
  end

  @impl true
  def handle_event("remove_question", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    questions = List.delete_at(socket.assigns.questions, index)

    questions =
      if questions == [] do
        [blank_question(0)]
      else
        Enum.with_index(questions, fn q, i -> %{q | "index" => i} end)
      end

    {:noreply, assign(socket, questions: questions)}
  end

  @impl true
  def handle_event("save", params, socket) do
    name = String.trim(params["name"] || "")
    description = String.trim(params["description"] || "")
    category = params["category"] || "brand_health"
    questions = update_questions_from_params(socket.assigns.questions, params)

    errors = validate_fields(name)
    question_errors = validate_questions(questions)

    has_errors = errors != %{} or Enum.any?(question_errors, &(&1 != nil))

    if has_errors do
      {:noreply, assign(socket, errors: errors, question_errors: question_errors)}
    else
      survey =
        SurveyPulse.Surveys.create_survey!(%{
          name: name,
          description: description,
          category: String.to_existing_atom(category)
        })

      for q <- questions do
        type = q["question_type"]
        {min, max} = scale_for_type(type, q["scale_min"], q["scale_max"])

        SurveyPulse.Surveys.create_question!(%{
          survey_id: survey.id,
          code: String.trim(q["code"]),
          text: String.trim(q["text"]),
          question_type: String.to_existing_atom(type),
          scale_min: min,
          scale_max: max
        })
      end

      {:noreply,
       socket
       |> put_flash(:info, "Survey \"#{survey.name}\" created")
       |> push_navigate(to: ~p"/surveys/#{survey.id}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="bg-white border-b border-gray-200">
        <div class="max-w-3xl mx-auto px-6 py-5">
          <div class="flex items-center gap-3 mb-2">
            <.link navigate={~p"/"} class="text-gray-400 hover:text-gray-600">
              <.icon name="hero-arrow-left" class="h-5 w-5" />
            </.link>
          </div>
          <h1 class="text-2xl font-semibold text-gray-900">Create Survey</h1>
        </div>
      </header>

      <main class="max-w-3xl mx-auto px-6 py-8 space-y-6">
        <form phx-change="validate" phx-submit="save" class="space-y-6">
          <div class="bg-white rounded-xl border border-gray-200 p-6 shadow-sm space-y-4">
            <h2 class="text-lg font-semibold text-gray-900">Survey Details</h2>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Survey Name</label>
              <input
                type="text"
                name="name"
                value={@name}
                class={[
                  "w-full rounded-lg border text-sm px-3 py-2",
                  if(@errors[:name], do: "border-red-300 focus:ring-red-500", else: "border-gray-300 focus:ring-indigo-500")
                ]}
                placeholder="e.g. Brand Health Tracker — Fizzy Cola"
              />
              <p :if={@errors[:name]} class="text-xs text-red-500 mt-1">{@errors[:name]}</p>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea
                name="description"
                rows="3"
                class="w-full rounded-lg border border-gray-300 text-sm px-3 py-2 focus:ring-indigo-500"
                placeholder="Brief description of this survey's purpose..."
              >{@description}</textarea>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Category</label>
              <select
                name="category"
                class="rounded-lg border-gray-300 text-sm py-2 pl-3 pr-8 focus:ring-indigo-500"
              >
                <option value="brand_health" selected={@category == "brand_health"}>Brand Health</option>
                <option value="ad_testing" selected={@category == "ad_testing"}>Ad Testing</option>
                <option value="concept_testing" selected={@category == "concept_testing"}>Concept Testing</option>
                <option value="product_testing" selected={@category == "product_testing"}>Product Testing</option>
              </select>
            </div>
          </div>

          <div class="bg-white rounded-xl border border-gray-200 p-6 shadow-sm space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-gray-900">Questions</h2>
              <button
                type="button"
                phx-click="add_question"
                class="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors"
              >
                <.icon name="hero-plus" class="h-3.5 w-3.5" />
                Add Question
              </button>
            </div>

            <div :for={{q, idx} <- Enum.with_index(@questions)} class="border border-gray-200 rounded-lg p-4 space-y-3">
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-gray-700">Question {idx + 1}</span>
                <button
                  :if={length(@questions) > 1}
                  type="button"
                  phx-click="remove_question"
                  phx-value-index={idx}
                  class="text-gray-400 hover:text-red-500 transition-colors"
                >
                  <.icon name="hero-trash" class="h-4 w-4" />
                </button>
              </div>
              <p :if={Enum.at(@question_errors, idx)} class="text-xs text-red-500">{Enum.at(@question_errors, idx)}</p>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-medium text-gray-500 mb-1">Code</label>
                  <input
                    type="text"
                    name={"q_#{idx}_code"}
                    value={q["code"]}
                    class="w-full rounded-lg border border-gray-300 text-sm px-3 py-1.5"
                    placeholder="e.g. AWARENESS"
                  />
                </div>
                <div>
                  <label class="block text-xs font-medium text-gray-500 mb-1">Type</label>
                  <select
                    name={"q_#{idx}_type"}
                    class="w-full rounded-lg border-gray-300 text-sm py-1.5 pl-2 pr-7"
                  >
                    <option value="likert" selected={q["question_type"] == "likert"}>Likert (1–5)</option>
                    <option value="nps" selected={q["question_type"] == "nps"}>NPS (0–10)</option>
                    <option value="scale" selected={q["question_type"] == "scale"}>Scale (custom)</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-500 mb-1">Question Text</label>
                <input
                  type="text"
                  name={"q_#{idx}_text"}
                  value={q["text"]}
                  class="w-full rounded-lg border border-gray-300 text-sm px-3 py-1.5"
                  placeholder="e.g. How aware are you of this brand?"
                />
              </div>
              <div :if={q["question_type"] == "scale"} class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-medium text-gray-500 mb-1">Scale Min</label>
                  <input
                    type="number"
                    name={"q_#{idx}_min"}
                    value={q["scale_min"]}
                    class="w-full rounded-lg border border-gray-300 text-sm px-3 py-1.5"
                  />
                </div>
                <div>
                  <label class="block text-xs font-medium text-gray-500 mb-1">Scale Max</label>
                  <input
                    type="number"
                    name={"q_#{idx}_max"}
                    value={q["scale_max"]}
                    class="w-full rounded-lg border border-gray-300 text-sm px-3 py-1.5"
                  />
                </div>
              </div>
            </div>
          </div>

          <button
            type="submit"
            class="w-full py-3 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 transition-colors"
          >
            Create Survey
          </button>
        </form>
      </main>
    </div>
    """
  end

  defp blank_question(index) do
    %{
      "index" => index,
      "code" => "",
      "text" => "",
      "question_type" => "likert",
      "scale_min" => "1",
      "scale_max" => "5"
    }
  end

  defp update_questions_from_params(questions, params) do
    Enum.with_index(questions, fn q, idx ->
      type = params["q_#{idx}_type"] || q["question_type"]

      %{
        q
        | "code" => params["q_#{idx}_code"] || q["code"],
          "text" => params["q_#{idx}_text"] || q["text"],
          "question_type" => type,
          "scale_min" => params["q_#{idx}_min"] || q["scale_min"],
          "scale_max" => params["q_#{idx}_max"] || q["scale_max"]
      }
    end)
  end

  defp validate_fields(name) do
    errors = %{}
    if String.trim(name) == "", do: Map.put(errors, :name, "Required"), else: errors
  end

  defp validate_questions(questions) do
    Enum.map(questions, fn q ->
      cond do
        String.trim(q["code"] || "") == "" -> "Code required"
        String.trim(q["text"] || "") == "" -> "Question text required"
        true -> nil
      end
    end)
  end

  defp scale_for_type("nps", _min, _max), do: {0, 10}
  defp scale_for_type("likert", _min, _max), do: {1, 5}

  defp scale_for_type(_type, min, max) do
    {parse_int(min, 1), parse_int(max, 5)}
  end

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(_, default), do: default
end
