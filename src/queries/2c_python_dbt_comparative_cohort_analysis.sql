/*
    Question 2c: Head-to-Head Comparison (Python and dbt)
    Author: Senior Data Engineer Candidate
    Purpose: Compare engagement quality (Score, Views, Velocity)
*/

WITH distinct_metrics AS (
    SELECT
        tags AS technology,
        COUNT(*) AS total_questions,
        
        -- volume engagement
        SUM(answer_count) AS total_answers,
        ROUND(AVG(answer_count), 2) AS avg_answers_per_q,
        
        -- success engagement
        ROUND(SAFE_DIVIDE(SUM(CASE WHEN accepted_answer_id IS NOT NULL THEN 1 ELSE 0 END), COUNT(*)), 4) AS accepted_rate,
        
        -- quality perception (score)
        ROUND(AVG(score), 2) AS avg_score,
        
        -- reach (views) - pre-aggregated to allow use in outer query
        SUM(view_count) AS total_views,
        ROUND(AVG(view_count), 0) AS avg_views_per_q
        
    FROM
        `bigquery-public-data.stackoverflow.posts_questions`
    WHERE
        tags IN ('python', 'dbt')
        AND EXTRACT(YEAR FROM creation_date) BETWEEN 2020 AND 2022
    GROUP BY
        1
)

SELECT
    technology,
    total_questions,
    avg_answers_per_q,
    accepted_rate,
    avg_score, -- python is negative (-0.15), dbt is positive (+1.29)
    avg_views_per_q,
    -- response velocity proxy: answers per 1k views
    ROUND(SAFE_DIVIDE(total_answers, total_views) * 1000, 4) AS answers_per_1k_views
FROM
    distinct_metrics
ORDER BY
    total_questions DESC;