/*
    Question 1a: Top Performing Tags
    Author: Senior Data Engineer Candidate
    Purpose: Identify individual tags with the highest resolution rates (Accepted Answers) in the current year.
    
    Statistical Threshold: P90 (>= 75 questions) to ensure statistical significance and eliminate small sample bias.
*/

WITH daily_questions AS (
    -- Base Filtering (project pruning & predicate pushdown)
    -- Initial filtering occurs to minimize memory usage in subsequent string operations
    SELECT 
        id,
        tags, 
        answer_count,
        -- Converts NULL accepted_answer_id to 0 for easier calculations
        CASE WHEN accepted_answer_id IS NOT NULL THEN 1 ELSE 0 END AS has_accepted_answer
    FROM 
        `bigquery-public-data.stackoverflow.posts_questions`
    WHERE 
        -- Hard filter on 2022 per data profiling findings
        EXTRACT(YEAR FROM creation_date) = 2022
        AND tags IS NOT NULL
),

exploded_tags AS (
    -- Unnesting (normalization)
    -- Explodes the 'tags' string into rows. 1 question with 3 tags becomes 3 rows.
    SELECT
        tag,
        answer_count,
        has_accepted_answer
    FROM 
        daily_questions,
        UNNEST(SPLIT(tags, '|')) AS tag
),

individual_tag_metrics AS (
    -- Aggregation per individual tag
    SELECT 
        'Individual Tag' AS dimension_type,
        tag AS dimension_name,
        COUNT(*) AS question_volume,
        SUM(answer_count) AS total_answers,
        SUM(has_accepted_answer) AS total_accepted,
        ROUND(AVG(answer_count), 2) AS avg_answers_per_question,
        ROUND(SAFE_DIVIDE(SUM(has_accepted_answer), COUNT(*)), 4) AS accepted_rate
    FROM 
        exploded_tags
    GROUP BY 
        tag
),

combination_metrics AS (
    -- Aggregation per tag combination (original context)
    SELECT 
        'Tag Combination' AS dimension_type,
        tags AS dimension_name,
        COUNT(*) AS question_volume,
        SUM(answer_count) AS total_answers,
        SUM(has_accepted_answer) AS total_accepted,
        ROUND(AVG(answer_count), 2) AS avg_answers_per_question,
        ROUND(SAFE_DIVIDE(SUM(has_accepted_answer), COUNT(*)), 4) AS accepted_rate
    FROM 
        daily_questions
    GROUP BY 
        tags
),

unified_analysis AS (
    -- Unifying and filtering for statistical significance
    -- Filters out noise (e.g., tags with 1 question/1 answer = 100% rate)
    SELECT * FROM individual_tag_metrics WHERE question_volume >= 75
    UNION ALL
    SELECT * FROM combination_metrics WHERE question_volume >= 20
)

-- Top 20 best performing tags (highest acceptance)
SELECT 
    *
FROM 
    unified_analysis
ORDER BY 
    accepted_rate DESC,
    question_volume DESC
LIMIT 20;