/*
    Question 2a: Year-Over-Year Growth & Response Ratio (Python and dbt)
    Author: Senior Data Engineer Candidate
    Purpose: Analyze the evolution of community engagement volume over the last decade.

    Scope: Posts tagged STRICTLY with 'python' or 'dbt'.
    NOTE: This strict filter excludes questions where 'dbt' is combined with other tags (e.g. 'dbt|sql')
*/

WITH filtered_posts AS (
    -- Base Filtering (project pruning & predicate pushdown)
    -- Initial filtering occurs to minimize memory usage in subsequent string operations
    SELECT
        tags AS tag_name,
        answer_count,
        EXTRACT(YEAR FROM creation_date) AS year
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
        COUNT(*) AS total_questions,
        SUM(answer_count) AS total_answers,
        -- Ratio: average answers per question
        ROUND(SAFE_DIVIDE(SUM(answer_count), COUNT(*)), 4) AS q_a_ratio
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
        q_a_ratio,
        -- Window function to get previous year's data
        LAG(q_a_ratio) OVER (PARTITION BY tag_name ORDER BY year) AS prev_year_ratio
    FROM
        annual_metrics
)

SELECT
    year,
    tag_name,
    total_questions,
    q_a_ratio,
    -- Calculate YoY percentage change
    ROUND(SAFE_DIVIDE(q_a_ratio - prev_year_ratio, prev_year_ratio) * 100, 2) AS ratio_yoy_pct
FROM
    yoy_calculations
ORDER BY
    tag_name, year;
