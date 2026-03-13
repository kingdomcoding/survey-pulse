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

    SurveyPulse.SampleData.generate!(survey.id, questions,
      wave_count: spec.wave_count,
      responses_per_wave: spec.responses_per_wave,
      pattern: spec.pattern
    )

    Logger.info("  Generated #{spec.wave_count} waves for #{survey.name}")
  end
end
