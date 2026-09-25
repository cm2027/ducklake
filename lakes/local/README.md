# Local DuckLake (DuckDB catalog + local filesystem)

The simplest DuckLake setup. Good for a first run and for single-client work.

- **Catalog:** DuckDB file `data/my_ducklake.ducklake`
- **Storage:** local folder `data/my_ducklake.ducklake.files/` (Parquet files)

## Run

From the repo root. Works on Linux, macOS and Windows (Docker Desktop with
Linux containers); PowerShell equivalents noted where commands differ.

```bash
# 1. create + seed the lake (mkdir first: the ./data bind mount must exist
#    host-owned, otherwise docker creates it as root and init can't write)
mkdir -p lakes/local/data
# PowerShell: New-Item -ItemType Directory -Force lakes/local/data | Out-Null
docker compose -f lakes/local/compose.yaml up init

# 2. inspect the files that were created
ls -R lakes/local/data
# PowerShell: Get-ChildItem -Recurse lakes/local/data

# 3. interactive shell
docker compose -f lakes/local/compose.yaml run --rm cli

# inside the shell:
#   LOAD ducklake;
#   ATTACH 'ducklake:my_ducklake.ducklake' AS local_lake;
#   USE local_lake;
#   FROM local_lake.snapshots();
#   SELECT * FROM clinic.clinics ORDER BY code;
```

Or run the tour non-interactively:

```bash
docker compose -f lakes/local/compose.yaml run --rm cli \
  -bail -echo -f /queries/queries.sql
```

Without docker (needs DuckDB >= 1.5.2):

```bash
mkdir -p lakes/local/data
cd lakes/local/data
duckdb -bail -echo -f ../init.sql
```

## What to look at

1. `FROM local_lake.snapshots();` one row per commit (schema, tables, inserts, update).
2. `SELECT * FROM clinic.clinics AT (VERSION => 3);` time travel (pick the id from snapshots()).
3. `FROM glob('my_ducklake.ducklake.files/**/*');` the Parquet files DuckLake wrote.
4. `FROM local_lake.settings();`, `data_path`, catalog type, extension version.

## Reset

```bash
docker compose -f lakes/local/compose.yaml down
rm -rf lakes/local/data
# PowerShell: Remove-Item -Recurse -Force lakes/local/data
```

> [!NOTE]
> Windows note
> `compose.yaml` runs the containers as `UID:GID 1000` so `./data` stays owned
> by you instead of root. If you hit permission errors on Docker Desktop,
> comment out the two `user:` lines to run as root instead (FS differs, and NTFS doesnt have the same model as POSIX).

## Limits

Single writer (DuckDB file as catalog). For multiple / remote clients see
[`../local-pg-s3/`](../local-pg-s3/).

## Note for host clients (python/go/java)

Inside docker the lake lives at `/data/my_ducklake.ducklake` and that absolute
path is what gets stored as `data_path`. From the host the same files are at
`lakes/local/data/...`, so override the stored path when attaching:

```sql
ATTACH 'ducklake:lakes/local/data/my_ducklake.ducklake' AS local_lake
  (DATA_PATH 'lakes/local/data/my_ducklake.ducklake.files/', OVERRIDE_DATA_PATH true);
```

The `cmd/*-example` clients in this repo do this automatically when you point
them at the local lake. Inside the `cli` container no override is needed.
