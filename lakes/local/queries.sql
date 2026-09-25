-- Handy queries for the local DuckLake. Run after `up init`, e.g.:
--   docker compose -f lakes/local/compose.yaml run --rm cli -bail -echo -f /queries/queries.sql
-- Or paste them into any DuckDB client attached to the lake.

LOAD ducklake;
ATTACH 'ducklake:my_ducklake.ducklake' AS local_lake;
USE local_lake;

-- What snapshots exist?
FROM local_lake.snapshots();

-- Current data
SELECT * FROM clinic.clinics ORDER BY code;

-- Time travel: an early snapshot holds the first insert (old hospital name),
-- the current version holds the update. Snapshot ids come from snapshots().
SELECT * FROM clinic.clinics AT (VERSION => 3) ORDER BY code;
SELECT * FROM clinic.clinics ORDER BY code;

-- Bigger table: average waiting time per department
SELECT department, count(*) AS n, avg(wait_minutes) AS avg_wait
FROM clinic.appointments GROUP BY department ORDER BY department;

-- Where do the Parquet files live?
SELECT * FROM glob('my_ducklake.ducklake.files/**/*');

-- Read a lake file directly (path from the glob above)
-- SELECT * FROM 'my_ducklake.ducklake.files/clinic/appointments/ducklake-*.parquet' LIMIT 10;

-- Lake settings / data path
FROM local_lake.settings();
