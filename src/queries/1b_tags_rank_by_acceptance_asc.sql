/*
    Question 1b: Worst Performing Tags
    Author: Senior Data Engineer Candidate
    Purpose: Identify individual tags with the lowest resolution rates (bottlenecks).
    
    Statistical Threshold: P90 (>= 75 questions) to avoid noise from one-off questions.
*/

WITH daily_questions AS (
    -- Base Filtering (project pruning & predicate pushdown)
    -- Initial filtering occurs to minimize memory usage in subsequent string operations
    SELECT 
        id,
        tags, 
        answer_count,
        CASE WHEN accepted_answer_id IS NOT NULL THEN 1 ELSE 0 END AS has_accepted_answer
    FROM 
        `bigquery-public-data.stackoverflow.posts_questions`
    WHERE 
        EXTRACT(YEAR FROM creation_date) = 2022
        AND tags IS NOT NULL
),

exploded_tags AS (
    SELECT
        tag,
        answer_count,
        has_accepted_answer
    FROM 
        daily_questions,
        UNNEST(SPLIT(tags, '|')) AS tag
),

tag_metrics AS (
    SELECT 
        tag,
        COUNT(*) AS question_volume,
        ROUND(AVG(answer_count), 2) AS avg_answers,
        ROUND(SAFE_DIVIDE(SUM(has_accepted_answer), COUNT(*)), 4) AS accepted_rate
    FROM 
        exploded_tags
    GROUP BY 
        tag
    HAVING 
        question_volume >= 75 -- P90 Threshold
)

-- Top 20 worst performing tags (lowest acceptance)
SELECT * FROM tag_metrics
ORDER BY accepted_rate ASC
LIMIT 20;