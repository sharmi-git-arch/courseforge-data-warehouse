-- CourseForge OLTP Schema — v2 (20 tables)
-- CS779 Term Project - Sharmila Gopal
-- Run this after: CREATE DATABASE courseforge;  then  \c courseforge
-- If re-running: DROP the old tables first, e.g. DROP TABLE IF EXISTS ... CASCADE;

-- Tables with no foreign key dependencies first
CREATE TABLE Instructor (
    InstructorID    INTEGER PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    bio             TEXT
);

CREATE TABLE Student (
    StudentID       INTEGER PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    email           VARCHAR(150) UNIQUE NOT NULL,
    signup_date     DATE NOT NULL
);

CREATE TABLE Skill (
    SkillID         INTEGER PRIMARY KEY,
    skill_name      VARCHAR(100) NOT NULL
);

CREATE TABLE Category (
    CategoryID      INTEGER PRIMARY KEY,
    category_name   VARCHAR(100) NOT NULL
);

CREATE TABLE Level (
    LevelID         INTEGER PRIMARY KEY,
    level_name      VARCHAR(50) NOT NULL
);

CREATE TABLE Coupon (
    CouponID        INTEGER PRIMARY KEY,
    coupon_code     VARCHAR(50) NOT NULL,
    discount_percent INTEGER NOT NULL CHECK (discount_percent BETWEEN 0 AND 100)
);

-- Course depends on Instructor, Category, Level
CREATE TABLE Course (
    CourseID        INTEGER PRIMARY KEY,
    InstructorID    INTEGER NOT NULL REFERENCES Instructor(InstructorID),
    CategoryID      INTEGER NOT NULL REFERENCES Category(CategoryID),
    LevelID         INTEGER NOT NULL REFERENCES Level(LevelID),
    title           VARCHAR(200) NOT NULL,
    price           NUMERIC(6,2) NOT NULL
);

-- Module depends on Course
CREATE TABLE Module (
    ModuleID        INTEGER PRIMARY KEY,
    CourseID        INTEGER NOT NULL REFERENCES Course(CourseID),
    title           VARCHAR(200) NOT NULL,
    sequence        INTEGER NOT NULL
);

-- Lesson depends on Module
CREATE TABLE Lesson (
    LessonID            INTEGER PRIMARY KEY,
    ModuleID            INTEGER NOT NULL REFERENCES Module(ModuleID),
    title               VARCHAR(200) NOT NULL,
    video_url           VARCHAR(255),
    duration_seconds    INTEGER
);

-- Quiz depends on Module
CREATE TABLE Quiz (
    QuizID          INTEGER PRIMARY KEY,
    ModuleID        INTEGER NOT NULL REFERENCES Module(ModuleID),
    title           VARCHAR(200) NOT NULL,
    max_score       INTEGER NOT NULL
);

-- QuizQuestion depends on Quiz
CREATE TABLE QuizQuestion (
    QuestionID      INTEGER PRIMARY KEY,
    QuizID          INTEGER NOT NULL REFERENCES Quiz(QuizID),
    question_text   TEXT NOT NULL,
    question_type   VARCHAR(30) NOT NULL
);

-- QuestionOption depends on QuizQuestion
CREATE TABLE QuestionOption (
    OptionID        INTEGER PRIMARY KEY,
    QuestionID      INTEGER NOT NULL REFERENCES QuizQuestion(QuestionID),
    option_text     VARCHAR(200) NOT NULL,
    is_correct      BOOLEAN NOT NULL
);

-- Enrollment depends on Student and Course
CREATE TABLE Enrollment (
    EnrollmentID    INTEGER PRIMARY KEY,
    StudentID       INTEGER NOT NULL REFERENCES Student(StudentID),
    CourseID        INTEGER NOT NULL REFERENCES Course(CourseID),
    enrolled_date   DATE NOT NULL,
    completion_date DATE
);

-- QuizAttempt depends on Quiz and Student
CREATE TABLE QuizAttempt (
    AttemptID           INTEGER PRIMARY KEY,
    QuizID              INTEGER NOT NULL REFERENCES Quiz(QuizID),
    StudentID           INTEGER NOT NULL REFERENCES Student(StudentID),
    attempt_number      INTEGER NOT NULL,
    score               INTEGER NOT NULL,
    time_spent_seconds  INTEGER NOT NULL,
    attempt_date        TIMESTAMP NOT NULL
);

-- StudentAnswer depends on QuizAttempt, QuizQuestion, QuestionOption
CREATE TABLE StudentAnswer (
    AnswerID            INTEGER PRIMARY KEY,
    AttemptID           INTEGER NOT NULL REFERENCES QuizAttempt(AttemptID),
    QuestionID          INTEGER NOT NULL REFERENCES QuizQuestion(QuestionID),
    SelectedOptionID    INTEGER NOT NULL REFERENCES QuestionOption(OptionID)
);

-- Review depends on Course and Student
CREATE TABLE Review (
    ReviewID        INTEGER PRIMARY KEY,
    CourseID        INTEGER NOT NULL REFERENCES Course(CourseID),
    StudentID       INTEGER NOT NULL REFERENCES Student(StudentID),
    rating          INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_date     DATE NOT NULL
);

-- CourseSkillTag: junction table, depends on Course and Skill
CREATE TABLE CourseSkillTag (
    CourseID        INTEGER NOT NULL REFERENCES Course(CourseID),
    SkillID         INTEGER NOT NULL REFERENCES Skill(SkillID),
    PRIMARY KEY (CourseID, SkillID)
);

-- Payment depends on Student, Course, Coupon
CREATE TABLE Payment (
    PaymentID       INTEGER PRIMARY KEY,
    StudentID       INTEGER NOT NULL REFERENCES Student(StudentID),
    CourseID        INTEGER NOT NULL REFERENCES Course(CourseID),
    CouponID        INTEGER REFERENCES Coupon(CouponID),
    amount          NUMERIC(6,2) NOT NULL,
    payment_date    DATE NOT NULL
);

-- Certificate depends on Student and Course
CREATE TABLE Certificate (
    CertificateID   INTEGER PRIMARY KEY,
    StudentID       INTEGER NOT NULL REFERENCES Student(StudentID),
    CourseID        INTEGER NOT NULL REFERENCES Course(CourseID),
    issue_date      DATE NOT NULL
);

-- InstructorPayout depends on Instructor and Payment
CREATE TABLE InstructorPayout (
    PayoutID        INTEGER PRIMARY KEY,
    InstructorID    INTEGER NOT NULL REFERENCES Instructor(InstructorID),
    PaymentID       INTEGER NOT NULL REFERENCES Payment(PaymentID),
    payout_amount   NUMERIC(6,2) NOT NULL,
    payout_date     DATE NOT NULL
);

