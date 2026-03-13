defmodule SurveyPulse.Analytics do
  @moduledoc false
  use Ash.Domain

  resources do
    resource SurveyPulse.Analytics.Response do
      define(:ingest_responses, action: :ingest, args: [:rows])
    end

    resource SurveyPulse.Analytics.WaveSummary do
      define(:wave_summary, action: :for_survey, args: [:survey_id])
      define(:wave_summary_filtered, action: :for_survey_filtered, args: [:survey_id, :filters])
    end

    resource SurveyPulse.Analytics.Breakdown do
      define(:demographic_breakdown,
        action: :for_question,
        args: [:survey_id, :question_id, :wave_id, :dimension]
      )
    end

    resource SurveyPulse.Analytics.Trend do
      define(:longitudinal_trend, action: :for_question, args: [:survey_id, :question_id])

      define(:longitudinal_trend_filtered,
        action: :for_question_filtered,
        args: [:survey_id, :question_id, :filters]
      )
    end
  end
end
