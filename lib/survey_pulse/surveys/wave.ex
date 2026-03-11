defmodule SurveyPulse.Surveys.Wave do
  @moduledoc false
  use Ash.Resource,
    domain: SurveyPulse.Surveys,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("waves")
    repo(SurveyPulse.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:survey_id, :wave_number, :label, :started_at, :ended_at])
    end

    read :for_survey do
      argument(:survey_id, :uuid, allow_nil?: false)
      filter(expr(survey_id == ^arg(:survey_id)))
      prepare(build(sort: [wave_number: :asc]))
    end

    read :by_id do
      argument(:id, :uuid, allow_nil?: false)
      get?(true)
      filter(expr(id == ^arg(:id)))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:wave_number, :integer, allow_nil?: false, public?: true)
    attribute(:label, :string, public?: true)
    attribute(:started_at, :utc_datetime, allow_nil?: false, public?: true)
    attribute(:ended_at, :utc_datetime, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :survey, SurveyPulse.Surveys.Survey, allow_nil?: false, public?: true
  end
end
