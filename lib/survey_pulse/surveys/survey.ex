defmodule SurveyPulse.Surveys.Survey do
  @moduledoc false
  use Ash.Resource,
    domain: SurveyPulse.Surveys,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("surveys")
    repo(SurveyPulse.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :description, :category])
    end

    read :list do
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :by_id do
      argument(:id, :uuid, allow_nil?: false)
      get?(true)
      filter(expr(id == ^arg(:id)))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)

    attribute(:category, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:brand_health, :ad_testing, :concept_testing, :product_testing]]
    )

    timestamps()
  end

  relationships do
    has_many :waves, SurveyPulse.Surveys.Wave
    has_many :questions, SurveyPulse.Surveys.Question
  end

  aggregates do
    count(:wave_count, :waves)

    first :latest_wave_number, :waves, :wave_number do
      sort(wave_number: :desc)
    end
  end
end
