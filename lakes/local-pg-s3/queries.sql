-- Tour queries for the postgres+garage DuckLake.
-- Fill in the three secrets first (see seed.sql), then run block by block.

LOAD ducklake; LOAD postgres; LOAD httpfs;
-- ... recreate s3_sec / pg_sec / lake_sec here (see seed.sql) ...
-- ATTACH 'ducklake:lake_sec' AS pg_lake;
-- USE pg_lake;

-- Snapshots (one row per commit)
FROM pg_lake.snapshots();

-- Current data
SELECT * FROM clinic.clinics ORDER BY code;

-- Time travel to the snapshot that holds the first insert
-- (look up the id in snapshots(); the update is one snapshot later)
-- SELECT * FROM clinic.clinics AT (VERSION => 3) ORDER BY code;

-- Bigger table: average waiting time per department
SELECT department, count(*) AS n, avg(wait_minutes) AS avg_wait
FROM clinic.appointments GROUP BY department ORDER BY department;

-- Lake settings: catalog_type=postgres, data_path=s3://...
FROM pg_lake.settings();

-- S3 objects live under s3://ducklake-data/data/ – check with:
--   docker compose exec garage /garage bucket info ducklake-data
