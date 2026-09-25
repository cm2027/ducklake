# Local Postgres + S3 DuckLake (multi-user capable)

Same demo data as [`../local/`](../local/), but with a real client/server split:

- **Catalog:** PostgreSQL (`postgres:17-alpine` container, db `ducklake_catalog`)
- **Storage:** S3-compatible object store ([Garage](https://garagehq.deuxfleurs.fr/) single node, bucket `ducklake-data`)

> [!NOTE]
> S3 is an AWS service and costs, but there are several open source ones with a
> compatible API. MinIO was the most used one for a while, but it has recently
> (last year) been deprecated and is unmaintained. Therefore we use
> [`garage`](https://garagehq.deuxfleurs.fr/quick_start/index.html) here, which
> like MinIO is an open source S3 compatible object store.

## Run

No setup needed: all dev credentials are hardcoded (compose.yaml, seed.sql,
garage-init scripts), so `docker compose` works with no `.env` file. To change
a value, export it or copy `.env.example` to `.env` – compose picks it up
automatically for interpolation.

From this directory (`lakes/local-pg-s3/`):

```bash
# 1. infra (only postgres + garage; the one-shot `seed` service is run
#    explicitly in step 3, after the bucket exists)
docker compose up -d postgres garage
docker compose ps         # both healthy

# 2. garage layout + bucket + key (idempotent, re-runnable)
./scripts/garage-init.sh
# PowerShell: .\scripts\garage-init.ps1

# 3. create + seed the lake (idempotent, re-runnable)
docker compose run --rm seed
```

Verify the S3 side:

```bash
docker compose exec garage /garage bucket info ducklake-data
```

Postgres side (catalog tables):

```bash
docker compose exec postgres psql -U ducklake -d ducklake_catalog -c '\dt'
```

The `seed` service runs the DuckDB CLI on the compose network, which is why
`seed.sql` uses the hostnames `postgres` and `garage:3900`. To run the same
statements from a DuckDB shell on your host, replace them with `127.0.0.1`
and `127.0.0.1:3900`.

## What to look at

Same tour as the local lake, but note the differences:

1. `FROM pg_lake.snapshots();` same snapshot model, metadata now in Postgres.
2. `FROM pg_lake.settings();` `catalog_type = postgres`,
   `data_path = s3://ducklake-data/data/`.
3. Small inserts are _inlined_ into Postgres by default (no S3 object yet);
   bigger inserts land as Parquet under `s3://ducklake-data/data/`.
4. Time travel works the same: `... AT (VERSION => <id>)`.

## Reset

```bash
docker compose down -v   # deletes postgres + garage volumes
```

Then re-run the three steps above.
