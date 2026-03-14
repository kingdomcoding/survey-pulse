defmodule SurveyPulse.SampleDataTest do
  use ExUnit.Case

  alias SurveyPulse.SampleData

  @question %{scale_min: 1, scale_max: 5, question_type: :likert}

  test "steady_growth produces ascending scores" do
    scores = for w <- 1..6, do: SampleData.base_score_for_question(@question, w, :steady_growth)
    assert scores == Enum.sort(scores)
    assert List.last(scores) > List.first(scores)
  end

  test "campaign_spike peaks at wave 3" do
    scores = for w <- 1..6, do: SampleData.base_score_for_question(@question, w, :campaign_spike)
    assert Enum.at(scores, 2) == Enum.max(scores)
  end

  test "iteration_improvement has step change at wave 5-6" do
    scores =
      for w <- 1..6, do: SampleData.base_score_for_question(@question, w, :iteration_improvement)

    early_avg = (Enum.at(scores, 0) + Enum.at(scores, 1) + Enum.at(scores, 2)) / 3
    late_avg = (Enum.at(scores, 4) + Enum.at(scores, 5)) / 2
    assert late_avg > early_avg + 0.3
  end

  test "NPS question uses wider noise band" do
    assert SampleData.noise_for_question_type(:nps) > SampleData.noise_for_question_type(:likert)
  end

  test "demographic bias: younger skews positive" do
    young = SampleData.demographic_bias("18-24", "north_america", :likert)
    old = SampleData.demographic_bias("65+", "north_america", :likert)
    assert young > old
  end
end
