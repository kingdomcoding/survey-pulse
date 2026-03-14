CREATE DATABASE IF NOT EXISTS survey_pulse_test;

CREATE TABLE IF NOT EXISTS survey_pulse_test.responses (
    id              UUID,
    survey_id       UUID,
    wave_id         UUID,
    question_id     UUID,
    respondent_id   UUID,
    score           Int32,
    age_group       LowCardinality(String),
    gender          LowCardinality(String),
    region          LowCardinality(String),
    responded_at    DateTime
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(responded_at)
ORDER BY (survey_id, wave_id, question_id, responded_at)
SETTINGS index_granularity = 8192;

CREATE TABLE IF NOT EXISTS survey_pulse_test.wave_question_metrics (
    survey_id       UUID,
    wave_id         UUID,
    question_id     UUID,
    age_group       LowCardinality(String),
    gender          LowCardinality(String),
    region          LowCardinality(String),
    response_count  AggregateFunction(count, UInt64),
    avg_score       AggregateFunction(avg, Int32),
    min_score       AggregateFunction(min, Int32),
    max_score       AggregateFunction(max, Int32)
) ENGINE = AggregatingMergeTree()
ORDER BY (survey_id, wave_id, question_id, age_group, gender, region);

CREATE MATERIALIZED VIEW IF NOT EXISTS survey_pulse_test.wave_question_metrics_mv
TO survey_pulse_test.wave_question_metrics
AS
SELECT
    survey_id,
    wave_id,
    question_id,
    age_group,
    gender,
    region,
    countState(*)          AS response_count,
    avgState(score)        AS avg_score,
    minState(score)        AS min_score,
    maxState(score)        AS max_score
FROM survey_pulse_test.responses
GROUP BY survey_id, wave_id, question_id, age_group, gender, region;
