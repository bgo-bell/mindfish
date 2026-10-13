-- Fake demo data for the mindfish database.
-- Every student here has an obviously fake name so they are easy to spot and remove.
-- Run ONCE. To remove this data later, run unseed.sql.

BEGIN;

-- Temporary helper (disappears when the session ends): adds a test and its section scores.
-- p_scores is JSON like '{"Math": 650, "Reading & Writing": 600}'.
CREATE FUNCTION pg_temp.add_attempt(
    p_first text, p_last text, p_exam exam_type, p_kind attempt_type,
    p_date date, p_scores jsonb
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_attempt bigint;
BEGIN
    INSERT INTO test_attempts (student_id, exam, kind, test_date)
    SELECT id, p_exam, p_kind, p_date
    FROM students
    WHERE first_name = p_first AND last_name = p_last
    RETURNING id INTO v_attempt;

    INSERT INTO section_scores (attempt_id, section_id, exam, score)
    SELECT v_attempt, s.id, s.exam, j.value::smallint
    FROM jsonb_each_text(p_scores) AS j
    JOIN sections s ON s.exam = p_exam AND s.name = j.key;
END $$;

INSERT INTO students (first_name, last_name) VALUES
    ('Hingle',      'McKringleberry'),
    ('Jackmerious', 'Tacktheritrix'),
    ('XWing',       'Aliciousness');

-- Hingle McKringleberry: SAT only, full history with steady improvement
SELECT pg_temp.add_attempt('Hingle','McKringleberry','SAT','initial', '2025-09-06', '{"Reading & Writing":520,"Math":540}');
SELECT pg_temp.add_attempt('Hingle','McKringleberry','SAT','practice','2025-10-18', '{"Reading & Writing":550,"Math":570}');
SELECT pg_temp.add_attempt('Hingle','McKringleberry','SAT','practice','2025-11-22', '{"Reading & Writing":580,"Math":600}');
SELECT pg_temp.add_attempt('Hingle','McKringleberry','SAT','practice','2026-01-10', '{"Reading & Writing":610,"Math":640}');
SELECT pg_temp.add_attempt('Hingle','McKringleberry','SAT','official','2026-03-14', '{"Reading & Writing":640,"Math":670}');

-- Jackmerious Tacktheritrix: ACT only, NO intake score
SELECT pg_temp.add_attempt('Jackmerious','Tacktheritrix','ACT','practice','2025-10-04', '{"English":21,"Math":19,"Reading":22,"Science":20}');
SELECT pg_temp.add_attempt('Jackmerious','Tacktheritrix','ACT','practice','2025-11-15', '{"English":23,"Math":21,"Reading":24,"Science":22}');
SELECT pg_temp.add_attempt('Jackmerious','Tacktheritrix','ACT','official','2025-12-13', '{"English":25,"Math":23,"Reading":26,"Science":24}');

-- XWing Aliciousness: took BOTH exams
SELECT pg_temp.add_attempt('XWing','Aliciousness','ACT','initial', '2025-08-20', '{"English":24,"Math":26,"Reading":25,"Science":23}');
SELECT pg_temp.add_attempt('XWing','Aliciousness','SAT','initial', '2025-08-27', '{"Reading & Writing":640,"Math":680}');
SELECT pg_temp.add_attempt('XWing','Aliciousness','SAT','practice','2025-10-11', '{"Reading & Writing":670,"Math":700}');
SELECT pg_temp.add_attempt('XWing','Aliciousness','ACT','practice','2025-10-25', '{"English":26,"Math":28,"Reading":27,"Science":25}');
SELECT pg_temp.add_attempt('XWing','Aliciousness','ACT','official','2025-12-13', '{"English":28,"Math":30,"Reading":29,"Science":27}');
SELECT pg_temp.add_attempt('XWing','Aliciousness','SAT','official','2026-03-14', '{"Reading & Writing":700,"Math":730}');

COMMIT;