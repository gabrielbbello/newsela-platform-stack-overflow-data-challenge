/*
    Question 2b: Year-Over-Year Success Rate (Python and dbt)
    Author: Senior Data Engineer Candidate
    Purpose: Analyze if the community's ability to solve problems is improving or declining.
    
    Metric: Accepted Answer Rate (Count of questions with an accepted solution / Total questions).
*/

WITH filtered_posts AS (
    -- Base Filtering (project pruning & predicate pushdown)
    -- Initial filtering occurs to minimize memory usage in subsequent string operations
    SELECT
        EXTRACT(YEAR FROM creation_date) AS year,
        tags AS tag_name,
        CASE WHEN accepted_answer_id IS NOT NULL THEN 1 ELSE 0 END as has_accepted
    FROM
        `bigquery-public-data.stackoverflow.posts_questions`
    WHERE
        tags IN ('python', 'dbt')
        AND creation_date BETWEEN '2012-01-01' AND '2022-12-31'
),

annual_metrics AS (
    SELECT
        year,
        tag_name,
        COUNT(*) as total_questions,
        -- Success rate calculation
        ROUND(SAFE_DIVIDE(SUM(has_accepted), COUNT(*)), 4) as accepted_rate
    FROM
        filtered_posts
    GROUP BY
        1, 2
),

yoy_calculations AS (
    SELECT
        year,
        tag_name,
        total_questions,
        accepted_rate,
        -- Window function to get previous year's data
        LAG(accepted_rate) OVER(PARTITION BY tag_name ORDER BY year) as prev_year_rate
    FROM
        annual_metrics
)

SELECT
    year,
    tag_name,
    total_questions,
    accepted_rate,
    -- Calculate YoY percentage change in rate
    ROUND(SAFE_DIVIDE(accepted_rate - prev_year_rate, prev_year_rate) * 100, 2) as rate_yoy_pct
FROM
    yoy_calculations
ORDER BY
    tag_name, year;