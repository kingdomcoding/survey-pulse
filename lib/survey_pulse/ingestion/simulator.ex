defmodule SurveyPulse.Ingestion.Simulator do
  @moduledoc false
  use GenServer

  alias SurveyPulse.Ingestion.Pipeline

  defstruct [:survey_id, :wave_id, :questions, :interval_ms, :batch_size, :wave_num]

  def start(opts) do
    GenServer.start(__MODULE__, opts, name: via(opts[:survey_id]))
  end

  def stop(survey_id) do
    case GenServer.whereis(via(survey_id)) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end
  end

  def running?(survey_id) do
    GenServer.whereis(via(survey_id)) != nil
  end

  defp via(survey_id), do: {:via, Registry, {SurveyPulse.SimulatorRegistry, survey_id}}

  @impl true
  def init(opts) do
    state = %__MODULE__{
      survey_id: Keyword.fetch!(opts, :survey_id),
      wave_id: Keyword.fetch!(opts, :wave_id),
      questions: Keyword.fetch!(opts, :questions),
      wave_num: Keyword.get(opts, :wave_num, 1),
      interval_ms: Keyword.get(opts, :interval_ms, 800),
      batch_size: Keyword.get(opts, :batch_size, 5)
    }

    Process.send_after(self(), :tick, state.interval_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    responses = generate_batch(state)

    Phoenix.PubSub.broadcast(
      SurveyPulse.PubSub,
      "simulation:#{state.survey_id}",
      {:simulation_batch, responses}
    )

    Pipeline.ingest(responses)
    Process.send_after(self(), :tick, state.interval_ms)
    {:noreply, state}
  end

  defp generate_batch(state) do
    for _i <- 1..state.batch_size, q <- state.questions do
      age_group = Enum.random(~w(18-24 25-34 35-44 45-54 55-64 65+))
      gender = Enum.random(~w(male female non_binary))
      region = Enum.random(~w(north_america europe asia_pacific latin_america))

      base = SurveyPulse.SampleData.base_score_for_question(q, state.wave_num, :steady_growth)
      demo_adj = SurveyPulse.SampleData.demographic_bias(age_group, region, q.question_type)
      noise = :rand.normal() * SurveyPulse.SampleData.noise_for_question_type(q.question_type)
      score = (base + demo_adj + noise) |> round() |> max(q.scale_min) |> min(q.scale_max)

      %{
        survey_id: state.survey_id,
        wave_id: state.wave_id,
        question_id: q.id,
        respondent_id: Ecto.UUID.generate(),
        score: score,
        age_group: age_group,
        gender: gender,
        region: region,
        responded_at: DateTime.utc_now()
      }
    end
  end
end
