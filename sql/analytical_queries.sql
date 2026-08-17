-- CourseForge Analytical Queries
-- CS779 Term Project - Sharmila Gopal
-- Run these against the courseforge database AFTER sp_run_full_etl() has populated
-- the warehouse. Each query is independent — run them one at a time, or all together.


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 1 — ROLLUP: Pass rate by category, with category subtotals
-- and a grand total row (ROLLUP is what generates those subtotal rows
-- automatically — that's the whole point of using it over a plain GROUP BY).
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    COALESCE(dc.category, 'ALL CATEGORIES') AS category,
    COUNT(*) AS total_attempts,
    SUM(f.pass_flag) AS passed_attempts,
    ROUND(100.0 * SUM(f.pass_flag) / COUNT(*), 1) AS pass_rate_pct
FROM fact_quiz_attempt f
JOIN dim_course dc ON dc.course_key = f.course_key
GROUP BY ROLLUP (dc.category)
ORDER BY category;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 2 — CUBE: Average score broken down every way by category AND
-- quarter — CUBE gives category-only subtotals, quarter-only subtotals,
-- AND the combined category+quarter breakdown, all in one result set.
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    COALESCE(dc.category, 'ALL CATEGORIES') AS category,
    COALESCE(dd.quarter::TEXT, 'ALL QUARTERS') AS quarter,
    COUNT(*) AS attempts,
    ROUND(AVG(f.score), 1) AS avg_score
FROM fact_quiz_attempt f
JOIN dim_course dc ON dc.course_key = f.course_key
JOIN dim_date dd ON dd.date_key = f.date_key
GROUP BY CUBE (dc.category, dd.quarter)
ORDER BY category, quarter;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 3 — Window function: rank instructors by average student score,
-- using RANK() so ties share a rank (unlike ROW_NUMBER()).
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    di.name AS instructor_name,
    COUNT(*) AS total_attempts,
    ROUND(AVG(f.score), 1) AS avg_score,
    RANK() OVER (ORDER BY AVG(f.score) DESC) AS score_rank
FROM fact_quiz_attempt f
JOIN dim_instructor di ON di.instructor_key = f.instructor_key
GROUP BY di.name
ORDER BY score_rank;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 4 — Time spent vs. score relationship: buckets attempts by how
-- long the student spent, then uses a window function to compare each
-- bucket's average score against the OVERALL average score at the same
-- time (no GROUP BY collapse needed for the comparison column).
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    time_bucket,
    COUNT(*) AS attempts,
    ROUND(AVG(score), 1) AS avg_score_in_bucket,
    ROUND(AVG(AVG(score)) OVER (), 1) AS avg_score_overall
FROM (
    SELECT
        score,
        CASE
            WHEN time_spent_seconds < 300 THEN '1. Under 5 min'
            WHEN time_spent_seconds < 600 THEN '2. 5-10 min'
            ELSE '3. Over 10 min'
        END AS time_bucket
    FROM fact_quiz_attempt
) bucketed
GROUP BY time_bucket
ORDER BY time_bucket;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 5 — Attempt-number funnel: how many students made it to a 2nd
-- or 3rd attempt, and what % that is relative to everyone who made a
-- 1st attempt. Uses a window function (FIRST_VALUE) to pull the attempt-1
-- count into every row for the percentage calculation.
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    attempt_number,
    COUNT(*) AS attempts_at_this_number,
    ROUND(100.0 * COUNT(*) / FIRST_VALUE(COUNT(*)) OVER (ORDER BY attempt_number), 1) AS pct_of_first_attempts
FROM fact_quiz_attempt
GROUP BY attempt_number
ORDER BY attempt_number;
