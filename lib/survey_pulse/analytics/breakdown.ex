defmodule SurveyPulse.Analytics.Breakdown do
  use Ash.Resource,
    domain: SurveyPulse.Analytics,
    data_layer: Ash.DataLayer.Simple

  actions do
    read :for_question do
      argument(:survey_id, :uuid, allow_nil?: false)
      argument(:question_id, :uuid, allow_nil?: false)
      argument(:wave_id, :uuid, allow_nil?: false)

      argument(:dimension, :atom,
        allow_nil?: false,
        constraints: [one_of: [:age_group, :gender, :region]]
      )

      manual(SurveyPulse.Analytics.ManualReads.ReadBreakdown)
    end
  end

  attributes do
    attribute(:segment, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:avg_score, :float, public?: true)
    attribute(:response_count, :integer, public?: true)
    attribute(:top2_box, :float, public?: true)
  end
end
