defmodule SurveyPulseWeb.SurveyLive do
  use SurveyPulseWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Survey")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 flex items-center justify-center">
      <p class="text-gray-500">Survey detail coming soon</p>
    </div>
    """
  end
end
