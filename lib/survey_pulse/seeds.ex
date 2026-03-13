defmodule SurveyPulse.Seeds do
  @moduledoc false
  require Logger

  @surveys [
    %{
      name: "Brand Health Tracker — Fizzy Cola",
      description:
        "Quarterly tracking study measuring awareness, consideration, and NPS for Fizzy Cola across key demographics.",
      category: :brand_health,
      pattern: :steady_growth,
      questions: [
        %{code: "AWARENESS", text: "How aware are you of Fizzy Cola?", type: :likert, min: 1, max: 5},
        %{code: "CONSIDER", text: "How likely are you to consider purchasing Fizzy Cola?", type: :likert, min: 1, max: 5},
        %{code: "NPS", text: "How likely are you to recommend Fizzy Cola to a friend?", type: :nps, min: 0, max: 10},
        %{code: "QUALITY", text: "How would you rate the overall quality of Fizzy Cola?", type: :likert, min: 1, max: 5},
        %{code: "VALUE", text: "How would you rate the value for money of Fizzy Cola?", type: :likert, min: 1, max: 5}
      ],
      wave_count: 8,
      responses_per_wave: 1200
    },
    %{
      name: "Ad Pre-Test — Summer Campaign",
      description:
        "Pre-test study for the Summer 2026 advertising campaign. Tests memorability, appeal, and purchase intent across three creative executions.",
      category: :ad_testing,
      pattern: :campaign_spike,
      questions: [
        %{code: "RECALL", text: "How memorable did you find this advertisement?", type: :likert, min: 1, max: 5},
        %{code: "APPEAL", text: "How appealing did you find this advertisement?", type: :likert, min: 1, max: 5},
        %{code: "INTENT", text: "After seeing this ad, how likely are you to purchase?", type: :likert, min: 1, max: 5},
        %{code: "EMOTION", text: "How did this advertisement make you feel? (1=very negative, 5=very positive)", type: :scale, min: 1, max: 5}
      ],
      wave_count: 6,
      responses_per_wave: 800
    },
    %{
      name: "Concept Test — Plant-Based Snack Line",
      description:
        "Iterative concept testing for new plant-based snack product line. Measures concept appeal, uniqueness, and purchase intent across development iterations.",
      category: :concept_testing,
      pattern: :iteration_improvement,
      questions: [
        %{code: "APPEAL", text: "How appealing is this product concept to you?", type: :likert, min: 1, max: 5},
        %{code: "UNIQUE", text: "How unique or different is this concept compared to existing products?", type: :likert, min: 1, max: 5},
        %{code: "INTENT", text: "How likely would you be to purchase this product?", type: :likert, min: 1, max: 5},
        %{code: "PRICE", text: "How reasonable is the expected price for this product?", type: :likert, min: 1, max: 5},
        %{code: "NPS", text: "How likely would you be to recommend this product?", type: :nps, min: 0, max: 10}
      ],
      wave_count: 10,
      responses_per_wave: 600
    },
    %{
      name: "Brand Health Tracker — FreshBrew Coffee",
      description:
        "Monthly tracking study for FreshBrew Coffee measuring brand perception, quality, and recommendation intent.",
      category: :brand_health,
      pattern: :steady_growth,
      questions: [
        %{code: "AWARENESS", text: "How aware are you of FreshBrew Coffee?", type: :likert, min: 1, max: 5},
        %{code: "QUALITY", text: "How would you rate the quality of FreshBrew Coffee?", type: :likert, min: 1, max: 5},
        %{code: "NPS", text: "How likely are you to recommend FreshBrew Coffee?", type: :nps, min: 0, max: 10}
      ],
      wave_count: 6,
      responses_per_wave: 900
    },
    %{
      name: "Ad Post-Test — Holiday TV Spot",
      description:
        "Post-campaign evaluation of the Holiday 2025 television advertisement. Measures recall, brand lift, and emotional response.",
      category: :ad_testing,
      pattern: :campaign_spike,
      questions: [
        %{code: "RECALL", text: "Do you remember seeing this advertisement?", type: :likert, min: 1, max: 5},
        %{code: "BRNDLIFT", text: "After seeing this ad, how do you feel about the brand?", type: :likert, min: 1, max: 5},
        %{code: "EMOTION", text: "How did this advertisement make you feel?", type: :scale, min: 1, max: 5},
        %{code: "INTENT", text: "How likely are you to purchase after seeing this ad?", type: :likert, min: 1, max: 5}
      ],
      wave_count: 4,
      responses_per_wave: 1000
    },
    %{
      name: "Product Test — Eco-Friendly Packaging",
      description:
        "Testing consumer response to new sustainable packaging designs across multiple iterations.",
      category: :product_testing,
      pattern: :iteration_improvement,
      questions: [
        %{code: "APPEAL", text: "How appealing is this packaging design?", type: :likert, min: 1, max: 5},
        %{code: "SUSTAIN", text: "How environmentally friendly does this packaging appear?", type: :likert, min: 1, max: 5},
        %{code: "PREF", text: "Would you prefer this packaging over the current design?", type: :likert, min: 1, max: 5},
        %{code: "NPS", text: "How likely would you recommend products with this packaging?", type: :nps, min: 0, max: 10}
      ],
      wave_count: 7,
      responses_per_wave: 500
    },
    %{
      name: "Concept Test — Ready-to-Drink Cocktails",
      description:
        "Evaluating consumer interest in a new line of premium ready-to-drink cocktails across flavor variants.",
      category: :concept_testing,
      pattern: :steady_growth,
      questions: [
        %{code: "APPEAL", text: "How appealing is this product concept?", type: :likert, min: 1, max: 5},
        %{code: "UNIQUE", text: "How unique is this compared to existing options?", type: :likert, min: 1, max: 5},
        %{code: "INTENT", text: "How likely would you be to purchase?", type: :likert, min: 1, max: 5},
        %{code: "NPS", text: "How likely would you recommend this product?", type: :nps, min: 0, max: 10}
      ],
      wave_count: 5,
      responses_per_wave: 700
    },
    %{
      name: "Brand Health Tracker — GlowSkin Cosmetics",
      description:
        "Quarterly brand tracking for GlowSkin Cosmetics measuring awareness, trust, and loyalty across demographics.",
      category: :brand_health,
      pattern: :campaign_spike,
      questions: [
        %{code: "AWARENESS", text: "How familiar are you with GlowSkin Cosmetics?", type: :likert, min: 1, max: 5},
        %{code: "TRUST", text: "How much do you trust GlowSkin as a brand?", type: :likert, min: 1, max: 5},
        %{code: "LOYALTY", text: "How likely are you to continue buying GlowSkin?", type: :likert, min: 1, max: 5},
        %{code: "NPS", text: "How likely are you to recommend GlowSkin?", type: :nps, min: 0, max: 10}
      ],
      wave_count: 8,
      responses_per_wave: 800
    },
    %{
      name: "Ad Pre-Test — Back to School Digital",
      description:
        "Pre-launch testing for back-to-school digital campaign targeting parents of school-age children.",
      category: :ad_testing,
      pattern: :iteration_improvement,
      questions: [
        %{code: "RECALL", text: "How memorable is this advertisement?", type: :likert, min: 1, max: 5},
        %{code: "RELEVANCE", text: "How relevant is this ad to you personally?", type: :likert, min: 1, max: 5},
        %{code: "INTENT", text: "How likely are you to click or learn more?", type: :likert, min: 1, max: 5}
      ],
      wave_count: 5,
      responses_per_wave: 600
    }
  ]

  @age_groups ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
  @genders ["male", "female", "non_binary"]
  @regions ["north_america", "europe", "asia_pacific", "latin_america"]

  def run do
    existing = SurveyPulse.Surveys.list_surveys!()

    if existing != [] do
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
          label: format_wave_label(wave_num, wave_start),
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
          wave_start,
          spec.pattern
        )

      responses
      |> Enum.chunk_every(5_000)
      |> Enum.each(fn batch ->
        SurveyPulse.Analytics.ingest_responses!(batch)
      end)

      Logger.info("  Wave #{wave_num} (#{wave.label}): #{length(responses)} responses")
    end
  end

  defp generate_wave_responses(survey_id, wave_id, questions, count, wave_num, wave_start, pattern) do
    for _i <- 1..count, question <- questions do
      respondent_id = Ecto.UUID.generate()
      age_group = Enum.random(@age_groups)
      gender = Enum.random(@genders)
      region = Enum.random(@regions)

      base_score = base_score_for_question(question, wave_num, pattern)
      demographic_adjustment = demographic_bias(age_group, region, question.question_type)
      noise_factor = noise_for_question_type(question.question_type)
      noise = :rand.normal() * noise_factor
      raw = base_score + demographic_adjustment + noise

      score = raw |> round() |> max(question.scale_min) |> min(question.scale_max)

      responded_at = DateTime.add(wave_start, :rand.uniform(14 * 86_400), :second)

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

  defp base_score_for_question(question, wave_num, pattern) do
    midpoint = (question.scale_min + question.scale_max) / 2

    case pattern do
      :steady_growth ->
        trend = wave_num * 0.1
        dip = if wave_num == 6, do: -0.4, else: 0.0
        recovery = if wave_num == 7, do: 0.3, else: 0.0
        midpoint + trend + dip + recovery

      :campaign_spike ->
        spike =
          cond do
            wave_num <= 2 -> 0.0
            wave_num == 3 -> 1.2
            wave_num == 4 -> 0.9
            wave_num == 5 -> 0.4
            true -> 0.1
          end

        midpoint + spike

      :iteration_improvement ->
        base = wave_num * 0.15
        plateau = if wave_num in [4, 5], do: -0.2, else: 0.0
        breakthrough = if wave_num >= 7, do: 0.5, else: 0.0
        midpoint - 0.5 + base + plateau + breakthrough
    end
  end

  defp demographic_bias(age_group, region, question_type) do
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

  defp noise_for_question_type(:nps), do: 1.8
  defp noise_for_question_type(:likert), do: 0.8
  defp noise_for_question_type(_), do: 1.0

  defp format_wave_label(wave_num, datetime) do
    month = Calendar.strftime(datetime, "%b %Y")
    "R#{wave_num} · #{month}"
  end
end
