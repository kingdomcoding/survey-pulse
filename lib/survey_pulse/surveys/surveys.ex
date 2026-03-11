defmodule SurveyPulse.Surveys do
  use Ash.Domain

  resources do
    resource SurveyPulse.Surveys.Survey do
      define(:list_surveys, action: :list)
      define(:get_survey, action: :by_id, args: [:id])
      define(:create_survey, action: :create)
    end

    resource SurveyPulse.Surveys.Wave do
      define(:list_waves, action: :for_survey, args: [:survey_id])
      define(:get_wave, action: :by_id, args: [:id])
      define(:create_wave, action: :create)
    end

    resource SurveyPulse.Surveys.Question do
      define(:list_questions, action: :for_survey, args: [:survey_id])
      define(:create_question, action: :create)
    end
  end
end
