defmodule SurveyPulseWeb.DashboardLive do
  use SurveyPulseWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "SurveyPulse")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 flex items-center justify-center">
      <p class="text-gray-500">Dashboard coming soon</p>
    </div>
    """
  end
end
