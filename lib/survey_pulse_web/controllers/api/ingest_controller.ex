defmodule SurveyPulseWeb.Api.IngestController do
  use SurveyPulseWeb, :controller

  alias SurveyPulse.Ingestion.Pipeline

  def create(conn, %{"responses" => responses}) when is_list(responses) do
    atomized =
      Enum.map(responses, fn r ->
        Map.new(r, fn {k, v} -> {String.to_existing_atom(k), v} end)
      end)

    Pipeline.ingest(atomized)

    json(conn, %{status: "accepted", count: length(responses)})
  end
end
