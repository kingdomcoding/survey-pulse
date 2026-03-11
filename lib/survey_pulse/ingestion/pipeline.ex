defmodule SurveyPulse.Ingestion.Pipeline do
  use Broadway

  alias SurveyPulse.Ingestion.ResponseProcessor

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Broadway.DummyProducer, []},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 4]
      ],
      batchers: [
        clickhouse: [
          concurrency: 2,
          batch_size: 5_000,
          batch_timeout: 2_000
        ]
      ]
    )
  end

  def ingest(responses) when is_list(responses) do
    messages =
      Enum.map(responses, fn response ->
        %Broadway.Message{
          data: response,
          acknowledger: Broadway.NoopAcknowledger.init()
        }
      end)

    Broadway.push_messages(__MODULE__, messages)
  end

  @impl true
  def handle_message(_, %Broadway.Message{data: data} = message, _context) do
    case ResponseProcessor.validate(data) do
      {:ok, validated} ->
        message
        |> Broadway.Message.update_data(fn _ -> validated end)
        |> Broadway.Message.put_batcher(:clickhouse)

      {:error, reason} ->
        Broadway.Message.failed(message, reason)
    end
  end

  @impl true
  def handle_batch(:clickhouse, messages, _batch_info, _context) do
    rows = Enum.map(messages, & &1.data)
    SurveyPulse.Analytics.ingest_responses!(rows)
    messages
  end
end
