-- Seed script for the postgres+garage DuckLake.
--
-- Catalog: PostgreSQL (`postgres` service, db `ducklake_catalog`)
-- Storage: Garage S3 (`garage` service, bucket `ducklake-data`)
--
-- Run with (from lakes/local-pg-s3/, after `./scripts/garage-init.sh`):
--   docker compose run --rm seed
--
-- This file runs *inside* the compose network, so it uses the service names
-- `postgres` and `garage` as hostnames. To paste these statements into a
-- DuckDB shell on your host instead, replace `postgres` -> `127.0.0.1` and
-- `garage:3900` -> `127.0.0.1:3900`.
-- Credentials below are the hardcoded dev defaults (also in compose.yaml and
-- the garage-init scripts). If you override them via the environment / `.env`,
-- update the secrets below to match.

INSTALL ducklake;
INSTALL postgres;
INSTALL httpfs;
LOAD ducklake;
LOAD postgres;
LOAD httpfs;

-- S3-compatible store (Garage, path style, plain HTTP)
CREATE OR REPLACE SECRET s3_sec (
    TYPE S3,
    PROVIDER config,
    KEY_ID 'GK0123456789abcdef01234567',
    SECRET '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    ENDPOINT 'garage:3900',
    URL_STYLE 'path',
    USE_SSL false,
    REGION 'garage'
);

-- Postgres catalog (matches the compose.yaml dev defaults)
CREATE OR REPLACE SECRET pg_sec (
    TYPE postgres,
    HOST 'postgres',
    PORT 5432,
    DATABASE 'ducklake_catalog',
    USER 'ducklake',
    PASSWORD 'ducklake'
);

-- DuckLake binding the two together. First ATTACH creates the lake.
CREATE OR REPLACE SECRET lake_sec (
    TYPE ducklake,
    METADATA_PATH '',
    DATA_PATH 's3://ducklake-data/data/',
    METADATA_PARAMETERS MAP {'TYPE': 'postgres', 'SECRET': 'pg_sec'}
);

ATTACH 'ducklake:lake_sec' AS pg_lake;
USE pg_lake;

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

-- Bigger insert to guarantee a visible S3 object even with inlining on.
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
FROM pg_lake.snapshots();
SELECT 'clinics:' AS info;
FROM clinic.clinics ORDER BY code;
SELECT 'appointment_count:' AS info, count(*) AS n FROM clinic.appointments;
