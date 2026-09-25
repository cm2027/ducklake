#!/usr/bin/env python3
"""Minimal DuckLake client demo (python).

Attaches one of this repo's lakes, writes a row, reads it back, and shows
snapshots() + time travel. Run from the repo root:

    mkdir -p lakes/local/data
    docker compose -f lakes/local/compose.yaml up init   # seed once
    python cmd/python-example/main.py                    # local lake
    python cmd/python-example/main.py --lake pg          # postgres+S3 lake

Needs `duckdb` (pip install -r requirements.txt in a venv).
"""

from __future__ import annotations

import argparse
import sys

try:
    import duckdb
except ImportError:
    sys.exit(
        "duckdb not installed: create a venv and `pip install -r requirements.txt`"
    )

# Dev defaults for the postgres+S3 lake. They match compose.yaml, seed.sql and
# the garage-init scripts, so --lake pg works out of the box. If you changed
# the credentials, edit them here.
PG_SECRET = (
    "HOST '127.0.0.1', PORT 5432, DATABASE 'ducklake_catalog', "
    "USER 'ducklake', PASSWORD 'ducklake'"
)
S3_KEY_ID = "GK0123456789abcdef01234567"
S3_SECRET_KEY = (
    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
)


def main() -> None:
    p = argparse.ArgumentParser(description="DuckLake python demo")
    p.add_argument("--lake", choices=["local", "pg"], default="local")
    p.add_argument(
        "--local-path",
        default="lakes/local/data/my_ducklake.ducklake",
        help="catalog file of the local lake (repo-root relative)",
    )
    a = p.parse_args()

    con = duckdb.connect()
    con.execute("INSTALL ducklake; INSTALL postgres; INSTALL httpfs;")
    con.execute("LOAD ducklake; LOAD postgres; LOAD httpfs;")

    if a.lake == "local":
        # The lake was seeded inside docker, where its stored data_path is
        # /data/.... From the host, override it with the host-side path
        # (see lakes/local/README.md).
        esc = a.local_path.replace("'", "''")
        con.execute(
            f"ATTACH 'ducklake:{esc}' AS lake "
            f"(DATA_PATH '{esc}.files/', OVERRIDE_DATA_PATH true);"
        )
    else:
        # S3-compatible object store (Garage: path style, plain HTTP).
        con.execute(
            "CREATE OR REPLACE SECRET s3_sec (TYPE S3, PROVIDER config, "
            f"KEY_ID '{S3_KEY_ID}', SECRET '{S3_SECRET_KEY}', "
            "ENDPOINT '127.0.0.1:3900', URL_STYLE 'path', USE_SSL false, "
            "REGION 'garage');"
        )
        # Postgres catalog.
        con.execute(
            "CREATE OR REPLACE SECRET pg_sec (TYPE postgres, "
            f"{PG_SECRET});"
        )
        # DuckLake binding the two together.
        con.execute(
            "CREATE OR REPLACE SECRET lake_sec (TYPE ducklake, METADATA_PATH '', "
            "DATA_PATH 's3://ducklake-data/data/', "
            "METADATA_PARAMETERS MAP {'TYPE': 'postgres', 'SECRET': 'pg_sec'});"
        )
        con.execute("ATTACH 'ducklake:lake_sec' AS lake;")

    con.execute("USE lake;")

    # Write a row...
    con.execute("CREATE SCHEMA IF NOT EXISTS clinic;")
    con.execute(
        "CREATE TABLE IF NOT EXISTS clinic.checkins (id INTEGER, note VARCHAR);"
    )
    con.execute(
        "INSERT INTO clinic.checkins "
        "SELECT coalesce(max(id), -1) + 1, 'check-in from python' "
        "FROM clinic.checkins;"
    )

    # ...read it back...
    print("checkins:")
    for row in con.execute("SELECT * FROM clinic.checkins ORDER BY id;").fetchall():
        print(" ", row)

    # ...and look at the lake metadata.
    print("settings:", con.execute("FROM lake.settings();").fetchall())
    snaps = con.execute("FROM lake.snapshots();").fetchall()
    print(f"snapshots ({len(snaps)}, last 3):")
    for s in snaps[-3:]:
        print(" ", s[0], s[3])

    # Time travel to the first snapshot holding table data. Our checkins table
    # may be younger than that snapshot, hence the try/except.
    target = next(
        (s[0] for s in snaps if "tables_inserted_into" in str(s[3])),
        snaps[-1][0],
    )
    print(f"time travel to VERSION => {target}:")
    try:
        rows = con.execute(
            f"SELECT * FROM clinic.checkins AT (VERSION => {target}) ORDER BY id;"
        ).fetchall()
        print(" ", rows)
    except Exception as e:
        print("  (unavailable at that version:", e, ")")


if __name__ == "__main__":
    main()
