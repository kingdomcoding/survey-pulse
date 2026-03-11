defmodule SurveyPulseWeb.Api.IngestController do
  use SurveyPulseWeb, :controller

  def create(conn, %{"responses" => responses}) when is_list(responses) do
    json(conn, %{status: "accepted", count: length(responses)})
  end
end
