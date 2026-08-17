-- Query A — Fact table's grain in action
SELECT *
FROM fact_quiz_attempt
LIMIT 5;

-- Query B — A simple aggregation (proves "few joins, fast")
SELECT
    ds.name AS student_name,
    dc.title AS course_title,
    COUNT(*) AS attempts,
    ROUND(AVG(f.score), 1) AS avg_score
FROM fact_quiz_attempt f
JOIN dim_student ds ON ds.student_key = f.student_key
JOIN dim_course dc ON dc.course_key = f.course_key
GROUP BY ds.name, dc.title
ORDER BY avg_score DESC
LIMIT 10;

-- Query C — SCD2 mechanism working
SELECT course_id, title, price, effective_date, end_date, is_current
FROM dim_course
ORDER BY course_id, effective_date;