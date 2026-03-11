defmodule SurveyPulse.Surveys.Question do
  @moduledoc false
  use Ash.Resource,
    domain: SurveyPulse.Surveys,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("questions")
    repo(SurveyPulse.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:survey_id, :code, :text, :question_type, :scale_min, :scale_max])
    end

    read :for_survey do
      argument(:survey_id, :uuid, allow_nil?: false)
      filter(expr(survey_id == ^arg(:survey_id)))
      prepare(build(sort: [code: :asc]))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:code, :string, allow_nil?: false, public?: true)
    attribute(:text, :string, allow_nil?: false, public?: true)

    attribute(:question_type, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:likert, :nps, :scale, :binary]]
    )

    attribute(:scale_min, :integer, default: 1, public?: true)
    attribute(:scale_max, :integer, default: 5, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :survey, SurveyPulse.Surveys.Survey, allow_nil?: false, public?: true
  end
end
