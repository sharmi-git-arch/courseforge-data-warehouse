-- Step 1
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name NOT LIKE 'dim_%'
  AND table_name NOT LIKE 'fact_%'
ORDER BY table_name;

-- Step 2 — Show Course table structure (proves normalization)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'course'
ORDER BY ordinal_position;

-- Step 3 — Join to show the reconstructed, human-readable data
SELECT
    c.CourseID,
    c.title AS course_title,
    cat.category_name,
    i.name AS instructor_name,
    c.price
FROM Course c
JOIN Category cat ON cat.CategoryID = c.CategoryID
JOIN Instructor i ON i.InstructorID = c.InstructorID
ORDER BY c.CourseID;

-- Step 4 — One-to-many in action (Course -> Enrollment)
SELECT
    c.title AS course_title,
    COUNT(e.EnrollmentID) AS total_enrollments
FROM Course c
LEFT JOIN Enrollment e ON e.CourseID = c.CourseID
GROUP BY c.CourseID, c.title
ORDER BY total_enrollments DESC;

-- Step 5 — Many-to-many via junction table (Course <-> Skill)
SELECT
    c.title AS course_title,
    sk.skill_name
FROM Course c
JOIN CourseSkillTag cst ON cst.CourseID = c.CourseID
JOIN Skill sk ON sk.SkillID = cst.SkillID
ORDER BY c.title;