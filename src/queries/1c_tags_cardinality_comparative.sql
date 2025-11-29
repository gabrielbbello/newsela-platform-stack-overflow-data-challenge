/*
    Question 1c: Tag Combinations Analysis
    Author: Senior Data Engineer Candidate
    Purpose: Analyze if combining tags yields better results than individual tags.

    Statistical Threshold: Minimum Sample Size >= 20 (Stability Threshold).
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

-- String combination analysis
combination_metrics AS (
    SELECT
        tags AS tag_combination,
        -- Calculate cardinality (how many tags in this combination)
        ARRAY_LENGTH(SPLIT(tags, '|')) AS tags_count,
        COUNT(*) AS question_volume,
        ROUND(AVG(answer_count), 2) AS avg_answers,
        ROUND(SAFE_DIVIDE(SUM(has_accepted_answer), COUNT(*)), 4) AS accepted_rate
    FROM
        daily_questions
    GROUP BY
        1, 2
    HAVING
        question_volume >= 20 -- stability threshold (approx P99.5)
)

-- Best combinations (filtering out single tags to focus on combinations)
SELECT * FROM combination_metrics
WHERE tags_count > 1
ORDER BY accepted_rate DESC
LIMIT 20;
