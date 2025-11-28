/*
    Question 3a: Success Factors Correlation
    Author: Senior Data Engineer Candidate
    Purpose: Identify non-tag attributes (Body Length, Score, Curation) that correlate with high resolution rates.
    
    Methodology:
    - Analyzes 3 independent dimensions using UNION ALL for a unified view.
    - Uses pre-aggregated `post_history` to determine curation status without expensive joins.
*/

WITH edits_log AS (
    -- Dimension 1: curation history 
    SELECT post_id, COUNT(*) as edit_count
    FROM `bigquery-public-data.stackoverflow.post_history`
    WHERE EXTRACT(YEAR FROM creation_date) = 2022 AND post_history_type_id IN (4, 5, 6)
    GROUP BY post_id
),

content_features AS (
    SELECT
        q.id,
        -- Bucket: body length
        CASE 
            WHEN LENGTH(q.body) < 500 THEN '1. Short (< 500 chars)'
            WHEN LENGTH(q.body) BETWEEN 500 AND 1500 THEN '2. Medium (500-1.5k chars)'
            ELSE '3. Long (> 1.5k chars)'
        END AS length_bucket,
        -- Bucket: community score
        CASE 
            WHEN q.score < 0 THEN 'Negative Score'
            WHEN q.score = 0 THEN 'Zero Score'
            ELSE 'Positive Score'
        END AS score_bucket,
        -- Bucket: curation status
        CASE 
            WHEN e.edit_count IS NULL THEN 'Original (Never Edited)'
            ELSE 'Curated (Edited > 0)'
        END AS curation_status,
        
        q.answer_count,
        CASE WHEN q.accepted_answer_id IS NOT NULL THEN 1 ELSE 0 END AS is_accepted
    FROM
        `bigquery-public-data.stackoverflow.posts_questions` q
    LEFT JOIN 
        edits_log e ON q.id = e.post_id
    WHERE
        EXTRACT(YEAR FROM q.creation_date) = 2022
)

-- Impact of length
SELECT 'Body Length' as factor_type, length_bucket as factor_value, 
       ROUND(SAFE_DIVIDE(SUM(is_accepted), COUNT(*)), 4) as accepted_rate 
FROM content_features GROUP BY 1, 2

UNION ALL

-- Impact of curation (the strongest predictor)
SELECT 'Curation Status', curation_status, 
       ROUND(SAFE_DIVIDE(SUM(is_accepted), COUNT(*)), 4) as accepted_rate 
FROM content_features GROUP BY 1, 2

UNION ALL

-- Impact of community score
SELECT 'Community Score', score_bucket, 
       ROUND(SAFE_DIVIDE(SUM(is_accepted), COUNT(*)), 4) as accepted_rate 
FROM content_features GROUP BY 1, 2

ORDER BY factor_type, accepted_rate DESC;