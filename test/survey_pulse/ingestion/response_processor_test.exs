defmodule SurveyPulse.Ingestion.ResponseProcessorTest do
  use ExUnit.Case

  alias SurveyPulse.Ingestion.ResponseProcessor

  @valid_response %{
    survey_id: "550e8400-e29b-41d4-a716-446655440000",
    wave_id: "550e8400-e29b-41d4-a716-446655440001",
    question_id: "550e8400-e29b-41d4-a716-446655440002",
    respondent_id: "550e8400-e29b-41d4-a716-446655440003",
    score: 4,
    age_group: "25-34",
    gender: "female",
    region: "europe"
  }

  test "validates a valid response" do
    assert {:ok, validated} = ResponseProcessor.validate(@valid_response)
    assert validated.survey_id == @valid_response.survey_id
    assert validated.score == 4
    assert validated.age_group == "25-34"
    assert validated.gender == "female"
    assert validated.region == "europe"
    assert validated.id != nil
  end

  test "returns error for missing survey_id" do
    response = Map.delete(@valid_response, :survey_id)
    assert {:error, "survey_id is required"} = ResponseProcessor.validate(response)
  end

  test "returns error for missing wave_id" do
    response = Map.delete(@valid_response, :wave_id)
    assert {:error, "wave_id is required"} = ResponseProcessor.validate(response)
  end

  test "returns error for missing question_id" do
    response = Map.delete(@valid_response, :question_id)
    assert {:error, "question_id is required"} = ResponseProcessor.validate(response)
  end

  test "returns error for invalid score" do
    response = Map.put(@valid_response, :score, 11)
    assert {:error, _} = ResponseProcessor.validate(response)
  end

  test "returns error for negative score" do
    response = Map.put(@valid_response, :score, -1)
    assert {:error, _} = ResponseProcessor.validate(response)
  end

  test "normalizes unknown age_group to unknown" do
    response = Map.put(@valid_response, :age_group, "invalid")
    assert {:ok, validated} = ResponseProcessor.validate(response)
    assert validated.age_group == "unknown"
  end

  test "normalizes nil gender to unknown" do
    response = Map.delete(@valid_response, :gender)
    assert {:ok, validated} = ResponseProcessor.validate(response)
    assert validated.gender == "unknown"
  end

  test "normalizes unknown region to unknown" do
    response = Map.put(@valid_response, :region, "mars")
    assert {:ok, validated} = ResponseProcessor.validate(response)
    assert validated.region == "unknown"
  end
end
