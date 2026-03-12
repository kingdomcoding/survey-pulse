defmodule SurveyPulse.SurveysTest do
  use SurveyPulse.DataCase

  alias SurveyPulse.Surveys

  describe "surveys" do
    test "create_survey! creates a survey" do
      survey =
        Surveys.create_survey!(%{
          name: "Test Survey",
          description: "A test survey",
          category: :brand_health
        })

      assert survey.name == "Test Survey"
      assert survey.category == :brand_health
    end

    test "list_surveys! returns surveys ordered by inserted_at desc" do
      s1 = Surveys.create_survey!(%{name: "First", category: :brand_health})
      s2 = Surveys.create_survey!(%{name: "Second", category: :ad_testing})

      surveys = Surveys.list_surveys!()
      assert length(surveys) == 2
      assert hd(surveys).id == s2.id
      assert List.last(surveys).id == s1.id
    end

    test "get_survey! returns a survey by id" do
      created = Surveys.create_survey!(%{name: "Find Me", category: :concept_testing})
      found = Surveys.get_survey!(created.id)
      assert found.id == created.id
      assert found.name == "Find Me"
    end

    test "aggregates wave_count and latest_wave_number" do
      survey = Surveys.create_survey!(%{name: "Agg Test", category: :brand_health})

      Surveys.create_wave!(%{
        survey_id: survey.id,
        wave_number: 1,
        label: "Wave 1",
        started_at: DateTime.utc_now()
      })

      Surveys.create_wave!(%{
        survey_id: survey.id,
        wave_number: 2,
        label: "Wave 2",
        started_at: DateTime.utc_now()
      })

      loaded = Surveys.get_survey!(survey.id, load: [:wave_count, :latest_wave_number])
      assert loaded.wave_count == 2
      assert loaded.latest_wave_number == 2
    end
  end

  describe "waves" do
    test "create_wave! creates a wave for a survey" do
      survey = Surveys.create_survey!(%{name: "Wave Test", category: :brand_health})

      wave =
        Surveys.create_wave!(%{
          survey_id: survey.id,
          wave_number: 1,
          label: "Jan 2025",
          started_at: ~U[2025-01-01 00:00:00Z]
        })

      assert wave.wave_number == 1
      assert wave.label == "Jan 2025"
    end

    test "list_waves! returns waves for a survey sorted by wave_number" do
      survey = Surveys.create_survey!(%{name: "Waves", category: :ad_testing})

      Surveys.create_wave!(%{
        survey_id: survey.id,
        wave_number: 2,
        label: "W2",
        started_at: DateTime.utc_now()
      })

      Surveys.create_wave!(%{
        survey_id: survey.id,
        wave_number: 1,
        label: "W1",
        started_at: DateTime.utc_now()
      })

      waves = Surveys.list_waves!(survey.id)
      assert length(waves) == 2
      assert hd(waves).wave_number == 1
    end
  end

  describe "questions" do
    test "create_question! creates a question for a survey" do
      survey = Surveys.create_survey!(%{name: "Q Test", category: :brand_health})

      question =
        Surveys.create_question!(%{
          survey_id: survey.id,
          code: "NPS",
          text: "Would you recommend?",
          question_type: :nps,
          scale_min: 0,
          scale_max: 10
        })

      assert question.code == "NPS"
      assert question.question_type == :nps
      assert question.scale_min == 0
      assert question.scale_max == 10
    end

    test "list_questions! returns questions for a survey sorted by code" do
      survey = Surveys.create_survey!(%{name: "Qs", category: :ad_testing})

      Surveys.create_question!(%{
        survey_id: survey.id,
        code: "ZZZ",
        text: "Last",
        question_type: :likert
      })

      Surveys.create_question!(%{
        survey_id: survey.id,
        code: "AAA",
        text: "First",
        question_type: :likert
      })

      questions = Surveys.list_questions!(survey.id)
      assert length(questions) == 2
      assert hd(questions).code == "AAA"
    end
  end
end
