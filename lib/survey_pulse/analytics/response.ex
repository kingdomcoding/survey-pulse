defmodule SurveyPulse.Analytics.Response do
  use Ash.Resource,
    domain: SurveyPulse.Analytics,
    data_layer: Ash.DataLayer.Simple

  resource do
    require_primary_key?(false)
  end

  actions do
    action :ingest, :map do
      argument(:rows, {:array, :map}, allow_nil?: false)

      run(fn input, _context ->
        rows = input.arguments.rows

        insertable =
          Enum.map(rows, fn row ->
            %{
              id: row[:id] || Ecto.UUID.generate(),
              survey_id: row.survey_id,
              wave_id: row.wave_id,
              question_id: row.question_id,
              respondent_id: row.respondent_id,
              score: row.score,
              age_group: row.age_group || "unknown",
              gender: row.gender || "unknown",
              region: row.region || "unknown",
              responded_at: row.responded_at || DateTime.utc_now()
            }
          end)

        {count, _} =
          SurveyPulse.ClickRepo.insert_all("responses", insertable,
            types: [
              id: "UUID",
              survey_id: "UUID",
              wave_id: "UUID",
              question_id: "UUID",
              respondent_id: "UUID",
              score: "Int32",
              age_group: "LowCardinality(String)",
              gender: "LowCardinality(String)",
              region: "LowCardinality(String)",
              responded_at: "DateTime"
            ]
          )

        Phoenix.PubSub.broadcast(
          SurveyPulse.PubSub,
          "analytics:updates",
          {:responses_ingested, count}
        )

        {:ok, %{inserted: count}}
      end)
    end
  end

  attributes do
    attribute(:id, :uuid, public?: true)
    attribute(:survey_id, :uuid, public?: true)
    attribute(:wave_id, :uuid, public?: true)
    attribute(:question_id, :uuid, public?: true)
    attribute(:respondent_id, :uuid, public?: true)
    attribute(:score, :integer, public?: true)
    attribute(:age_group, :string, public?: true)
    attribute(:gender, :string, public?: true)
    attribute(:region, :string, public?: true)
    attribute(:responded_at, :utc_datetime, public?: true)
  end
end
