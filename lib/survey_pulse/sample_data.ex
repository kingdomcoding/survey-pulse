defmodule SurveyPulse.SampleData do
  @moduledoc false

  @age_groups ~w(18-24 25-34 35-44 45-54 55-64 65+)
  @genders ~w(male female non_binary)
  @regions ~w(north_america europe asia_pacific latin_america)

  def generate!(survey_id, questions, opts \\ []) do
    wave_count = Keyword.get(opts, :wave_count, 6)
    responses_per_wave = Keyword.get(opts, :responses_per_wave, 500)
    pattern = Keyword.get(opts, :pattern, :steady_growth)
    base_date = ~U[2025-01-01 00:00:00Z]

    for wave_num <- 1..wave_count do
      wave_date = base_date |> DateTime.to_date() |> Date.shift(month: wave_num - 1)
      wave_start = DateTime.new!(wave_date, ~T[00:00:00], "Etc/UTC")
      wave_end = DateTime.add(wave_start, 14, :day)

      wave =
        SurveyPulse.Surveys.create_wave!(%{
          survey_id: survey_id,
          wave_number: wave_num,
          label: format_wave_label(wave_num, wave_start),
          started_at: wave_start,
          ended_at: wave_end
        })

      responses =
        for _i <- 1..responses_per_wave, question <- questions do
          respondent_id = Ecto.UUID.generate()
          age_group = Enum.random(@age_groups)
          gender = Enum.random(@genders)
          region = Enum.random(@regions)

          base_score = base_score_for_question(question, wave_num, pattern)
          demo_adj = demographic_bias(age_group, region, question.question_type)
          noise = :rand.normal() * noise_for_question_type(question.question_type)
          raw = base_score + demo_adj + noise
          score = raw |> round() |> max(question.scale_min) |> min(question.scale_max)

          %{
            survey_id: survey_id,
            wave_id: wave.id,
            question_id: question.id,
            respondent_id: respondent_id,
            score: score,
            age_group: age_group,
            gender: gender,
            region: region,
            responded_at: DateTime.add(wave_start, :rand.uniform(14 * 86_400), :second)
          }
        end

      responses
      |> Enum.chunk_every(5_000)
      |> Enum.each(&SurveyPulse.Analytics.ingest_responses!/1)

      wave
    end
  end

  def base_score_for_question(question, wave_num, pattern) do
    range = question.scale_max - question.scale_min
    midpoint = (question.scale_min + question.scale_max) / 2

    case pattern do
      :steady_growth ->
        midpoint - range * 0.15 + wave_num * (range * 0.06)

      :campaign_spike ->
        boost =
          case wave_num do
            1 -> 0.0
            2 -> 0.0
            3 -> range * 0.25
            4 -> range * 0.18
            5 -> range * 0.06
            _ -> range * 0.02
          end

        midpoint - range * 0.05 + boost

      :iteration_improvement ->
        step =
          case wave_num do
            1 -> 0.0
            2 -> range * 0.02
            3 -> range * 0.05
            4 -> range * 0.05
            5 -> range * 0.15
            _ -> range * 0.22
          end

        midpoint - range * 0.12 + step
    end
  end

  def demographic_bias(age_group, region, question_type) do
    age_effect =
      case {age_group, question_type} do
        {"18-24", :nps} -> 0.8
        {"18-24", _} -> 0.15
        {"25-34", :nps} -> 0.4
        {"25-34", _} -> 0.1
        {"55-64", :nps} -> -0.3
        {"55-64", _} -> -0.1
        {"65+", :nps} -> -0.5
        {"65+", _} -> -0.15
        _ -> 0.0
      end

    region_effect =
      case region do
        "asia_pacific" -> 0.2
        "latin_america" -> 0.15
        "europe" -> -0.1
        _ -> 0.0
      end

    age_effect + region_effect
  end

  def noise_for_question_type(:nps), do: 1.8
  def noise_for_question_type(:likert), do: 0.8
  def noise_for_question_type(_), do: 1.0

  def format_wave_label(wave_num, datetime) do
    month = Calendar.strftime(datetime, "%b %Y")
    "R#{wave_num} · #{month}"
  end
end
