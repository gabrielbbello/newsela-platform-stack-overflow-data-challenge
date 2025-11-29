/*
    Question 3b: Weekend Engagement Analysis
    Author: Senior Data Engineer Candidate
    Purpose: Test the hypothesis that questions posted on weekends perform worse due to lower traffic.

    Note: BigQuery `EXTRACT(DAYOFWEEK)` returns 1 for Sunday and 7 for Saturday.
*/

WITH daily_features AS (
    SELECT
        answer_count,
        EXTRACT(DAYOFWEEK FROM creation_date) AS day_number,
        CASE
            WHEN EXTRACT(DAYOFWEEK FROM creation_date) IN (1, 7) THEN 'Weekend'
            ELSE 'Weekday'
        END AS day_type,
        CASE WHEN accepted_answer_id IS NOT NULL THEN 1 ELSE 0 END AS is_accepted
    FROM
        `bigquery-public-data.stackoverflow.posts_questions`
    WHERE
        EXTRACT(YEAR FROM creation_date) = 2022
)

SELECT
    day_type,
    COUNT(*) AS total_questions,
    -- Volume share
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS volume_share_pct,
    -- Success rate
    ROUND(SAFE_DIVIDE(SUM(is_accepted), COUNT(*)), 4) AS accepted_rate
FROM
    daily_features
GROUP BY
    day_type
ORDER BY
    accepted_rate DESC;
