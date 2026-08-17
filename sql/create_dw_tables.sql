-- CourseForge Data Warehouse Schema (Star Schema)
-- CS779 Term Project - Sharmila Gopal
-- Run this in the SAME courseforge database, AFTER the OLTP tables already exist.
-- These are separate tables living alongside your OLTP tables (same DB, different
-- "layer" — this mirrors how a real warehouse often sits in its own schema/database,
-- simplified here into one DB for the class project).

CREATE TABLE dim_student (
    student_key     INTEGER PRIMARY KEY,
    student_id      INTEGER NOT NULL,
    name            VARCHAR(100) NOT NULL,
    signup_cohort   VARCHAR(7) NOT NULL   -- 'YYYY-MM'
);

CREATE TABLE dim_instructor (
    instructor_key      INTEGER PRIMARY KEY,
    instructor_id        INTEGER NOT NULL,
    name                 VARCHAR(100) NOT NULL
);

CREATE TABLE dim_quiz (
    quiz_key        INTEGER PRIMARY KEY,
    quiz_id         INTEGER NOT NULL,
    quiz_title      VARCHAR(200) NOT NULL,
    module_number   INTEGER,
    max_score       INTEGER NOT NULL
);

-- dim_course is the Type 2 Slowly Changing Dimension:
-- course_key is a SURROGATE key (auto-generated, unique per version of a course).
-- course_id is the NATURAL key (the real CourseID from OLTP — repeats across versions).
CREATE TABLE dim_course (
    course_key      SERIAL PRIMARY KEY,
    course_id       INTEGER NOT NULL,
    title           VARCHAR(200) NOT NULL,
    category        VARCHAR(100),
    price           NUMERIC(6,2) NOT NULL,
    effective_date  DATE NOT NULL,
    end_date        DATE,               -- NULL means "still active"
    is_current      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE dim_date (
    date_key    INTEGER PRIMARY KEY,   -- format YYYYMMDD
    full_date   DATE NOT NULL,
    day         INTEGER NOT NULL,
    month       INTEGER NOT NULL,
    quarter     INTEGER NOT NULL,
    year        INTEGER NOT NULL
);

CREATE TABLE fact_quiz_attempt (
    attempt_key         SERIAL PRIMARY KEY,
    student_key         INTEGER NOT NULL REFERENCES dim_student(student_key),
    course_key          INTEGER NOT NULL REFERENCES dim_course(course_key),
    instructor_key      INTEGER NOT NULL REFERENCES dim_instructor(instructor_key),
    quiz_key            INTEGER NOT NULL REFERENCES dim_quiz(quiz_key),
    date_key            INTEGER NOT NULL REFERENCES dim_date(date_key),
    score               INTEGER NOT NULL,
    max_score           INTEGER NOT NULL,
    time_spent_seconds  INTEGER NOT NULL,
    attempt_number      INTEGER NOT NULL,
    pass_flag           INTEGER NOT NULL
);
