defmodule SurveyPulse.Analytics.Trend do
  @moduledoc false
  use Ash.Resource,
    domain: SurveyPulse.Analytics,
    data_layer: Ash.DataLayer.Simple

  actions do
    read :for_question do
      argument(:survey_id, :uuid, allow_nil?: false)
      argument(:question_id, :uuid, allow_nil?: false)

      manual(SurveyPulse.Analytics.ManualReads.ReadTrend)
    end

    read :for_question_filtered do
      argument(:survey_id, :uuid, allow_nil?: false)
      argument(:question_id, :uuid, allow_nil?: false)
      argument(:filters, :map, default: %{})

      manual(SurveyPulse.Analytics.ManualReads.ReadTrend)
    end
  end

  attributes do
    attribute(:wave_id, :uuid, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:question_id, :uuid, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:wave_label, :string, public?: true)
    attribute(:wave_number, :integer, public?: true)
    attribute(:response_count, :integer, public?: true)
    attribute(:avg_score, :float, public?: true)
    attribute(:delta, :float, public?: true)
    attribute(:pct_change, :float, public?: true)
    attribute(:significant?, :boolean, public?: true)
  end
end
