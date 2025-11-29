/*
    Query: 3c_latency_time_to_first_answer.sql
    Objective: Analyze Engagement Velocity (Comment Speed & Answer Latency).
    Hypothesis: Faster engagement (The "Golden Hour") leads to higher resolution rates.

    Technical Approach:
    - Uses `TIMESTAMP_DIFF` to calculate minutes between Question creation and First Answer.
    - Leverages Window Functions (`RANK`) to identify the very first answer per thread.
    - Buckets `comment_count` to analyze friction velocity.
*/

-- Comment velocity (proxy for clarity/friction)
WITH comment_velocity AS (
    SELECT
        CASE
            WHEN comment_count = 0 THEN '0. Silent (Direct Answer)'
            WHEN comment_count = 1 THEN '1. Friction (Needs Clarification)'
            ELSE '2. High Engagement (>1 Comments)'
        END AS metric_bucket,
        COUNT(*) AS total_questions,
        ROUND(SAFE_DIVIDE(SUM(CASE WHEN accepted_answer_id IS NOT NULL THEN 1 ELSE 0 END), COUNT(*)), 4)
            AS accepted_rate
    FROM
        `bigquery-public-data.stackoverflow.posts_questions`
    WHERE
        EXTRACT(YEAR FROM creation_date) = 2022
    GROUP BY 1
),

-- Answer velocity
first_answers AS (
    SELECT
        a.parent_id,
        MIN(a.creation_date) AS first_answer_date
    FROM `bigquery-public-data.stackoverflow.posts_answers` AS a
    WHERE EXTRACT(YEAR FROM a.creation_date) = 2022
    GROUP BY 1
),

time_to_answer AS (
    SELECT
        q.id,
        TIMESTAMP_DIFF(fa.first_answer_date, q.creation_date, MINUTE) AS minutes_to_answer,
        CASE WHEN q.accepted_answer_id IS NOT NULL THEN 1 ELSE 0 END AS is_accepted
    FROM `bigquery-public-data.stackoverflow.posts_questions` AS q
    INNER JOIN first_answers AS fa ON q.id = fa.parent_id
    WHERE EXTRACT(YEAR FROM q.creation_date) = 2022
)

SELECT
    '1. Comment Velocity' AS metric_type,
    metric_bucket,
    total_questions AS volume,
    accepted_rate
FROM comment_velocity

UNION ALL

SELECT
    '2. Answer Latency' AS metric_type,
    CASE
        WHEN minutes_to_answer < 15 THEN '1. Immediate (< 15 min)'
        WHEN minutes_to_answer BETWEEN 15 AND 60 THEN '2. Golden Hour (1 hour)'
        WHEN minutes_to_answer BETWEEN 61 AND 1440 THEN '3. Same Day (24 hours)'
        ELSE '4. Late (> 1 day)'
    END AS metric_bucket,
    COUNT(*) AS volume,
    ROUND(SAFE_DIVIDE(SUM(is_accepted), COUNT(*)), 4) AS accepted_rate
FROM time_to_answer
GROUP BY 1, 2

ORDER BY metric_type ASC, accepted_rate DESC;
