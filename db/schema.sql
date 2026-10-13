-- ACT/SAT student progress tracker: PostgreSQL schema
-- Total scores are NOT stored; they are calculated from section scores
-- (SAT = sum of sections, ACT = rounded average of sections) in the attempt_totals view.

CREATE TYPE exam_type AS ENUM ('ACT', 'SAT');
CREATE TYPE attempt_type AS ENUM ('initial', 'practice', 'official');

-- Students
CREATE TABLE students (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  TEXT NOT NULL,
    last_name   TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lookup table: which sections exist for each exam, and their score ranges
CREATE TABLE sections (
    id         SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    exam       exam_type NOT NULL,
    name       TEXT NOT NULL,
    min_score  SMALLINT NOT NULL,
    max_score  SMALLINT NOT NULL,
    in_total   BOOLEAN NOT NULL DEFAULT true,  -- false for sections excluded from the total (e.g. ACT Writing)
    UNIQUE (exam, name),
    UNIQUE (id, exam)           -- lets score rows prove section and test match
);

INSERT INTO sections (exam, name, min_score, max_score) VALUES
    ('SAT', 'Reading & Writing', 200, 800),
    ('SAT', 'Math',              200, 800),
    ('ACT', 'English',           1,   36),
    ('ACT', 'Math',              1,   36),
    ('ACT', 'Reading',           1,   36),
    ('ACT', 'Science',           1,   36);
-- Optional later: INSERT INTO sections (exam, name, min_score, max_score, in_total)
--                 VALUES ('ACT', 'Writing', 2, 12, false);

-- One row per test taken: initial diagnostic, practice test, or official exam
CREATE TABLE test_attempts (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id  BIGINT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    exam        exam_type NOT NULL,
    kind        attempt_type NOT NULL,
    test_date   DATE NOT NULL,
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id, exam)
);

CREATE INDEX idx_attempts_student_date ON test_attempts (student_id, exam, test_date);

-- At most one initial score per student per exam
CREATE UNIQUE INDEX uniq_initial_per_student_exam
    ON test_attempts (student_id, exam) WHERE kind = 'initial';

-- Section breakdown for each attempt
CREATE TABLE section_scores (
    attempt_id  BIGINT NOT NULL,
    section_id  SMALLINT NOT NULL,
    exam        exam_type NOT NULL,
    score       SMALLINT NOT NULL,
    PRIMARY KEY (attempt_id, section_id),
    -- these two keys guarantee an ACT test can't get SAT sections
    FOREIGN KEY (attempt_id, exam) REFERENCES test_attempts (id, exam) ON DELETE CASCADE,
    FOREIGN KEY (section_id, exam) REFERENCES sections (id, exam)
);

-- Calculated totals. total_score is NULL until every counted section has a score.
--   SAT: sum of sections (400-1600)
--   ACT: average of sections, rounded to nearest whole number, .5 rounds up (1-36)
CREATE VIEW attempt_totals AS
SELECT a.id AS attempt_id,
       a.student_id,
       a.exam,
       a.kind,
       a.test_date,
       CASE
           WHEN COUNT(*) FILTER (WHERE sec.in_total) =
                (SELECT COUNT(*) FROM sections s2 WHERE s2.exam = a.exam AND s2.in_total)
           THEN CASE a.exam
                    WHEN 'SAT' THEN (SUM(ss.score) FILTER (WHERE sec.in_total))::int
                    WHEN 'ACT' THEN (ROUND(AVG(ss.score) FILTER (WHERE sec.in_total)))::int
                END
       END AS total_score
FROM test_attempts a
LEFT JOIN section_scores ss ON ss.attempt_id = a.id
LEFT JOIN sections sec      ON sec.id = ss.section_id
GROUP BY a.id, a.student_id, a.exam, a.kind, a.test_date;

-- One row per section score with the calculated total, ready for charts
CREATE VIEW score_history AS
SELECT s.id AS student_id,
       s.first_name,
       s.last_name,
       t.exam,
       t.kind,
       t.test_date,
       t.total_score,
       sec.name AS section,
       ss.score AS section_score
FROM students s
JOIN attempt_totals t       ON t.student_id = s.id
LEFT JOIN section_scores ss ON ss.attempt_id = t.attempt_id
LEFT JOIN sections sec      ON sec.id = ss.section_id
ORDER BY s.last_name, s.first_name, t.exam, t.test_date;