defmodule SurveyPulse.Analytics.WaveSummary do
  @moduledoc false
  use Ash.Resource,
    domain: SurveyPulse.Analytics,
    data_layer: Ash.DataLayer.Simple

  actions do
    read :for_survey do
      argument(:survey_id, :uuid, allow_nil?: false)

      manual(SurveyPulse.Analytics.ManualReads.ReadWaveSummary)
    end

    read :for_survey_filtered do
      argument(:survey_id, :uuid, allow_nil?: false)
      argument(:filters, :map, default: %{})

      manual(SurveyPulse.Analytics.ManualReads.ReadWaveSummary)
    end
  end

  attributes do
    attribute(:wave_id, :uuid, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:question_id, :uuid, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:response_count, :integer, public?: true)
    attribute(:avg_score, :float, public?: true)
    attribute(:min_score, :integer, public?: true)
    attribute(:max_score, :integer, public?: true)
  end
end
