-- Seed script for the local DuckLake.
--
-- Catalog: DuckDB file  (/data/my_ducklake.ducklake inside the container,
--                        ./lakes/local/data/ on the host)
-- Storage: local filesystem (/data/my_ducklake.ducklake.files/)
--
-- Run with:
--   docker compose -f lakes/local/compose.yaml up init
-- Or without docker (needs DuckDB >= 1.5.2 with ducklake support):
--   duckdb -c "READ 'lakes/local/init.sql'", from repo root, after mkdir -p lakes/local/data
--   (the script uses relative paths, so run it with lakes/local/data as CWD)

INSTALL ducklake;
LOAD ducklake;

-- Disable data inlining so every INSERT lands in a Parquet file and the
-- demo shows real lake files. Comment this out to use the default (10).
ATTACH 'ducklake:my_ducklake.ducklake' AS local_lake (DATA_INLINING_ROW_LIMIT 0);
USE local_lake;

CREATE SCHEMA IF NOT EXISTS clinic;

CREATE TABLE IF NOT EXISTS clinic.clinics (
    code VARCHAR,
    name VARCHAR,
    city VARCHAR
);

-- Idempotent seed: only insert when empty.
INSERT INTO clinic.clinics
SELECT * FROM (VALUES
    ('KAR', 'Karolinska University Hospital', 'Stockholm'),
    ('SOS', 'Södersjukhuset', 'Stockholm'),
    ('MAS', 'Skåne University Hospital', 'Malmö')
) AS seed(code, name, city)
WHERE NOT EXISTS (SELECT 1 FROM clinic.clinics);

-- Small demo mutation so `snapshots()` / time travel have something to show.
-- Only runs once (no row with the new name yet).
UPDATE clinic.clinics
SET name = 'Karolinska University Hospital Solna'
WHERE code = 'KAR' AND name = 'Karolinska University Hospital';

-- Bigger insert to guarantee a visible Parquet file even with inlining on.
CREATE TABLE IF NOT EXISTS clinic.appointments (
    appointment_id INTEGER,
    clinic_code VARCHAR,
    department VARCHAR,
    wait_minutes DOUBLE
);

INSERT INTO clinic.appointments
SELECT
    range AS appointment_id,
    (['KAR', 'SOS', 'MAS'])[range % 3 + 1] AS clinic_code,
    (['cardiology', 'oncology', 'pediatrics', 'orthopedics', 'radiology'])[range % 5 + 1] AS department,
    (range % 60) + 5 AS wait_minutes
FROM range(1000) tbl(range)
WHERE NOT EXISTS (SELECT 1 FROM clinic.appointments);

SELECT 'snapshots:' AS info;
FROM local_lake.snapshots();
SELECT 'clinics:' AS info;
FROM clinic.clinics ORDER BY code;
SELECT 'appointment_count:' AS info, count(*) AS n FROM clinic.appointments;
