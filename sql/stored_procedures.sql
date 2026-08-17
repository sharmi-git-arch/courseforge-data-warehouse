-- CourseForge ETL Stored Procedures
-- CS779 Term Project - Sharmila Gopal
--
-- These procedures move data from the OLTP schema into the star schema
-- warehouse. Run this AFTER both create_oltp_tables_v2.sql and
-- create_dw_tables.sql, and after the OLTP tables are populated.
--
-- Procedures, in the order they should be called:
--   1. sp_load_dim_student
--   2. sp_load_dim_instructor
--   3. sp_load_dim_quiz
--   4. sp_load_dim_date
--   5. sp_load_dim_course_scd2   <-- the Type 2 SCD logic
--   6. sp_load_fact_quiz_attempt
--   7. sp_run_full_etl           
-- ═══════════════════════════════════════════════════════════════════════
-- 1. dim_student — simple dimension, no history tracking needed
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_load_dim_student()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Upsert: insert new students, update existing ones if their name changed.
    -- (We treat Student as a "Type 1" dimension here — no history needed for name.)
    INSERT INTO dim_student (student_key, student_id, name, signup_cohort)
    SELECT
        s.StudentID,
        s.StudentID,
        s.name,
        TO_CHAR(s.signup_date, 'YYYY-MM')
    FROM Student s
    ON CONFLICT (student_key) DO UPDATE
        SET name = EXCLUDED.name,
            signup_cohort = EXCLUDED.signup_cohort;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════
-- 2. dim_instructor — simple dimension
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_load_dim_instructor()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO dim_instructor (instructor_key, instructor_id, name)
    SELECT i.InstructorID, i.InstructorID, i.name
    FROM Instructor i
    ON CONFLICT (instructor_key) DO UPDATE
        SET name = EXCLUDED.name;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════
-- 3. dim_quiz — simple dimension, pulls module_number via a join
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_load_dim_quiz()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO dim_quiz (quiz_key, quiz_id, quiz_title, module_number, max_score)
    SELECT q.QuizID, q.QuizID, q.title, m.sequence, q.max_score
    FROM Quiz q
    JOIN Module m ON m.ModuleID = q.ModuleID
    ON CONFLICT (quiz_key) DO UPDATE
        SET quiz_title = EXCLUDED.quiz_title,
            module_number = EXCLUDED.module_number,
            max_score = EXCLUDED.max_score;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════
-- 4. dim_date — generates one row per calendar day covering all quiz
--    attempt dates currently in the OLTP data
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_load_dim_date()
LANGUAGE plpgsql
AS $$
DECLARE
    min_d DATE;
    max_d DATE;
BEGIN
    SELECT MIN(attempt_date::date), MAX(attempt_date::date)
    INTO min_d, max_d
    FROM QuizAttempt;

    INSERT INTO dim_date (date_key, full_date, day, month, quarter, year)
    SELECT
        CAST(TO_CHAR(d, 'YYYYMMDD') AS INTEGER),
        d,
        EXTRACT(DAY FROM d)::INTEGER,
        EXTRACT(MONTH FROM d)::INTEGER,
        EXTRACT(QUARTER FROM d)::INTEGER,
        EXTRACT(YEAR FROM d)::INTEGER
    FROM generate_series(min_d, max_d, INTERVAL '1 day') AS d
    ON CONFLICT (date_key) DO NOTHING;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════
-- 5. dim_course — TYPE 2 SLOWLY CHANGING DIMENSION
--    For each course, compare its CURRENT
--    price/title/category in OLTP against the row in dim_course marked
--    is_current = TRUE.
--      - If nothing changed: do nothing.
--      - If something changed: expire the old row (set end_date,
--        is_current = FALSE) and insert a brand-new row with a new
--        surrogate key, is_current = TRUE.
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_load_dim_course_scd2()
LANGUAGE plpgsql
AS $$
DECLARE
    src RECORD;
    curr RECORD;
BEGIN
    -- Loop through every course currently in OLTP
    FOR src IN
        SELECT c.CourseID, c.title, cat.category_name AS category, c.price
        FROM Course c
        JOIN Category cat ON cat.CategoryID = c.CategoryID
    LOOP
        -- Find that course's CURRENT row in the warehouse (if any)
        SELECT * INTO curr
        FROM dim_course
        WHERE course_id = src.CourseID AND is_current = TRUE;

        IF NOT FOUND THEN
            -- Brand new course (including the very first ETL run, when the
            -- warehouse is empty): its first version should be effective
            -- from the start of recorded history, not "today" — otherwise
            -- historical fact rows dated before today would have no
            -- matching dim_course version to join to.
            INSERT INTO dim_course (course_id, title, category, price, effective_date, end_date, is_current)
            VALUES (src.CourseID, src.title, src.category, src.price, DATE '2000-01-01', NULL, TRUE);

        ELSIF curr.price <> src.price OR curr.title <> src.title OR curr.category <> src.category THEN
            -- Something changed: this is the SCD Type 2 event.
            -- Step 1: expire the old row.
            UPDATE dim_course
            SET end_date = CURRENT_DATE - INTERVAL '1 day',
                is_current = FALSE
            WHERE course_key = curr.course_key;

            -- Step 2: insert the new version as a brand-new row / new surrogate key.
            INSERT INTO dim_course (course_id, title, category, price, effective_date, end_date, is_current)
            VALUES (src.CourseID, src.title, src.category, src.price, CURRENT_DATE, NULL, TRUE);
        END IF;
        -- ELSE: nothing changed, do nothing (this is what keeps SCD2 from
        -- creating a new row every single run).
    END LOOP;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════
-- 6. fact_quiz_attempt — the fact table load.
--    The key SCD2-aware step: for each attempt, find whichever dim_course
--    row was ACTIVE on that attempt's date (not just whichever is current
--    today) — this is what keeps historical facts pointing at the correct
--    historical price.
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_load_fact_quiz_attempt()
LANGUAGE plpgsql
AS $$
BEGIN
    
    TRUNCATE TABLE fact_quiz_attempt RESTART IDENTITY;

    INSERT INTO fact_quiz_attempt
        (student_key, course_key, instructor_key, quiz_key, date_key,
         score, max_score, time_spent_seconds, attempt_number, pass_flag)
    SELECT
        qa.StudentID,
        dc.course_key,                          -- resolved below, SCD2-aware
        c.InstructorID,
        qa.QuizID,
        CAST(TO_CHAR(qa.attempt_date, 'YYYYMMDD') AS INTEGER),
        qa.score,
        q.max_score,
        qa.time_spent_seconds,
        qa.attempt_number,
        CASE WHEN qa.score >= 60 THEN 1 ELSE 0 END
    FROM QuizAttempt qa
    JOIN Quiz q          ON q.QuizID = qa.QuizID
    JOIN Module m        ON m.ModuleID = q.ModuleID
    JOIN Course c        ON c.CourseID = m.CourseID
    -- The important join: pick the dim_course row whose effective/end date
    -- range actually contains this attempt's date — NOT just "is_current".
    JOIN dim_course dc
        ON dc.course_id = c.CourseID
        AND qa.attempt_date::date >= dc.effective_date
        AND (dc.end_date IS NULL OR qa.attempt_date::date <= dc.end_date);
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════
-- 7. Master procedure — runs the full pipeline in the correct order
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_run_full_etl()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sp_load_dim_student();
    CALL sp_load_dim_instructor();
    CALL sp_load_dim_quiz();
    CALL sp_load_dim_date();
    CALL sp_load_dim_course_scd2();   -- must run before the fact load
    CALL sp_load_fact_quiz_attempt(); -- depends on dim_course being loaded
    RAISE NOTICE 'ETL complete.';
END;
$$;
