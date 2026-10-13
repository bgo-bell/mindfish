-- Removes ONLY the fake students created by seed.sql.
-- Their tests and section scores are deleted automatically (ON DELETE CASCADE).
-- Real students are not touched.

DELETE FROM students
WHERE (first_name, last_name) IN (
    ('Hingle',      'McKringleberry'),
    ('Jackmerious', 'Tacktheritrix'),
    ('XWing',       'Aliciousness')
);


