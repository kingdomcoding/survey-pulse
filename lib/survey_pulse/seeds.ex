defmodule SurveyPulse.Seeds do
  require Logger

  @surveys [
    %{
      name: "Brand Health Tracker — Fizzy Cola",
      description:
        "Quarterly tracking study measuring awareness, consideration, and NPS for Fizzy Cola across key demographics.",
      category: :brand_health,
      questions: [
        %{
          code: "AWARENESS",
          text: "How aware are you of Fizzy Cola?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "CONSIDER",
          text: "How likely are you to consider purchasing Fizzy Cola?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "NPS",
          text: "How likely are you to recommend Fizzy Cola to a friend?",
          type: :nps,
          min: 0,
          max: 10
        },
        %{
          code: "QUALITY",
          text: "How would you rate the overall quality of Fizzy Cola?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "VALUE",
          text: "How would you rate the value for money of Fizzy Cola?",
          type: :likert,
          min: 1,
          max: 5
        }
      ],
      wave_count: 8,
      responses_per_wave: 1200
    },
    %{
      name: "Ad Pre-Test — Summer Campaign",
      description:
        "Pre-test study for the Summer 2026 advertising campaign. Tests memorability, appeal, and purchase intent across three creative executions.",
      category: :ad_testing,
      questions: [
        %{
          code: "RECALL",
          text: "How memorable did you find this advertisement?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "APPEAL",
          text: "How appealing did you find this advertisement?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "INTENT",
          text: "After seeing this ad, how likely are you to purchase?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "EMOTION",
          text: "How did this advertisement make you feel? (1=very negative, 5=very positive)",
          type: :scale,
          min: 1,
          max: 5
        }
      ],
      wave_count: 6,
      responses_per_wave: 800
    },
    %{
      name: "Concept Test — Plant-Based Snack Line",
      description:
        "Iterative concept testing for new plant-based snack product line. Measures concept appeal, uniqueness, and purchase intent across development iterations.",
      category: :concept_testing,
      questions: [
        %{
          code: "APPEAL",
          text: "How appealing is this product concept to you?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "UNIQUE",
          text: "How unique or different is this concept compared to existing products?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "INTENT",
          text: "How likely would you be to purchase this product?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "PRICE",
          text: "How reasonable is the expected price for this product?",
          type: :likert,
          min: 1,
          max: 5
        },
        %{
          code: "NPS",
          text: "How likely would you be to recommend this product?",
          type: :nps,
          min: 0,
          max: 10
        }
      ],
      wave_count: 10,
      responses_per_wave: 600
    }
  ]

  @age_groups ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
  @genders ["male", "female", "non_binary"]
  @regions ["north_america", "europe", "asia_pacific", "latin_america"]

  def run do
    existing = SurveyPulse.Surveys.list_surveys!()

    if length(existing) > 0 do
      Logger.info("Surveys already exist, skipping seed.")
      :ok
    else
      Logger.info("Seeding survey data...")

      for survey_spec <- @surveys do
        seed_survey(survey_spec)
      end

      Logger.info("Seeding complete.")
    end
  end

  defp seed_survey(spec) do
    survey =
      SurveyPulse.Surveys.create_survey!(%{
        name: spec.name,
        description: spec.description,
        category: spec.category
      })

    Logger.info("Created survey: #{survey.name}")

    questions =
      Enum.map(spec.questions, fn q ->
        SurveyPulse.Surveys.create_question!(%{
          survey_id: survey.id,
          code: q.code,
          text: q.text,
          question_type: q.type,
          scale_min: q.min,
          scale_max: q.max
        })
      end)

    base_date = ~U[2025-01-01 00:00:00Z]

    for wave_num <- 1..spec.wave_count do
      wave_start = DateTime.add(base_date, (wave_num - 1) * 30, :day)
      wave_end = DateTime.add(wave_start, 14, :day)

      wave =
        SurveyPulse.Surveys.create_wave!(%{
          survey_id: survey.id,
          wave_number: wave_num,
          label: format_wave_label(wave_start),
          started_at: wave_start,
          ended_at: wave_end
        })

      responses =
        generate_wave_responses(
          survey.id,
          wave.id,
          questions,
          spec.responses_per_wave,
          wave_num,
          wave_start
        )

      responses
      |> Enum.chunk_every(5_000)
      |> Enum.each(fn batch ->
        SurveyPulse.Analytics.ingest_responses!(batch)
      end)

      Logger.info("  Wave #{wave_num} (#{wave.label}): #{length(responses)} responses")
    end
  end

  defp generate_wave_responses(survey_id, wave_id, questions, count, wave_num, wave_start) do
    for _i <- 1..count, question <- questions do
      respondent_id = Ecto.UUID.generate()
      age_group = Enum.random(@age_groups)
      gender = Enum.random(@genders)
      region = Enum.random(@regions)

      base_score = base_score_for_question(question, wave_num)
      demographic_adjustment = demographic_bias(age_group, region)
      noise = :rand.normal() * 0.5
      raw = base_score + demographic_adjustment + noise

      score = raw |> round() |> max(question.scale_min) |> min(question.scale_max)

      responded_at = DateTime.add(wave_start, :rand.uniform(14 * 86400), :second)

      %{
        survey_id: survey_id,
        wave_id: wave_id,
        question_id: question.id,
        respondent_id: respondent_id,
        score: score,
        age_group: age_group,
        gender: gender,
        region: region,
        responded_at: responded_at
      }
    end
  end

  defp base_score_for_question(question, wave_num) do
    midpoint = (question.scale_min + question.scale_max) / 2
    trend = wave_num * 0.05
    dip = if wave_num in [4, 5], do: -0.3, else: 0.0
    midpoint + trend + dip
  end

  defp demographic_bias(age_group, region) do
    age_adj =
      case age_group do
        "18-24" -> 0.2
        "25-34" -> 0.1
        "55-64" -> -0.1
        "65+" -> -0.2
        _ -> 0.0
      end

    region_adj =
      case region do
        "north_america" -> 0.1
        "asia_pacific" -> 0.15
        "latin_america" -> -0.05
        _ -> 0.0
      end

    age_adj + region_adj
  end

  defp format_wave_label(datetime) do
    month = datetime |> DateTime.to_date() |> Date.beginning_of_month()
    Calendar.strftime(month, "%b %Y")
  end
end
