defmodule SurveyPulse.Ingestion.ResponseProcessor do
  @valid_age_groups ~w(18-24 25-34 35-44 45-54 55-64 65+)
  @valid_genders ~w(male female non_binary prefer_not_to_say)
  @valid_regions ~w(north_america europe asia_pacific latin_america africa middle_east)

  def validate(data) when is_map(data) do
    with {:ok, survey_id} <- validate_uuid(data, :survey_id),
         {:ok, wave_id} <- validate_uuid(data, :wave_id),
         {:ok, question_id} <- validate_uuid(data, :question_id),
         {:ok, respondent_id} <- validate_uuid(data, :respondent_id),
         {:ok, score} <- validate_score(data) do
      {:ok,
       %{
         id: Ecto.UUID.generate(),
         survey_id: survey_id,
         wave_id: wave_id,
         question_id: question_id,
         respondent_id: respondent_id,
         score: score,
         age_group: normalize_segment(data[:age_group], @valid_age_groups),
         gender: normalize_segment(data[:gender], @valid_genders),
         region: normalize_segment(data[:region], @valid_regions),
         responded_at: data[:responded_at] || DateTime.utc_now()
       }}
    end
  end

  defp validate_uuid(data, field) do
    case Map.get(data, field) do
      nil -> {:error, "#{field} is required"}
      value when is_binary(value) -> {:ok, value}
    end
  end

  defp validate_score(data) do
    case data[:score] do
      score when is_integer(score) and score >= 0 and score <= 10 -> {:ok, score}
      _ -> {:error, "score must be integer 0-10"}
    end
  end

  defp normalize_segment(nil, _valid), do: "unknown"
  defp normalize_segment(value, valid), do: if(value in valid, do: value, else: "unknown")
end
