# ducklake examples for cm2027

In this repository you will find examples for how to use ducklake.

There are multiple different ways of running ducklake, this repo showcases two different ways:

- with duckdb as the meta store and the local filesystem for the raw storage (where the parquet files will live), see [`lakes/local/`](lakes/local/)
- with postgresql as the meta store and an s3 compatible object store as the raw storage, see [`lakes/local-pg-s3/`](lakes/local-pg-s3/)

> [!NOTE]
> s3 is an aws service and costs, but there are several open source ones that have an compatible API.
> minio was the most used one for a while, but it has recently (last year) been deprecated and is unmaintained.
> Therefore we will use [`garage`](https://garagehq.deuxfleurs.fr/quick_start/index.html) for this example, which like minio is an open source s3 compatible object store.

For simple reproducability `docker` with compose v2 (`docker compose`) is used.
Client examples in `Java` and `Python` live under [`cmd/`](cmd/).

## Requirements

- `git` and `docker` with compose v2. On Windows that means
  [Docker Desktop](https://www.docker.com/products/docker-desktop/) with Linux
  containers (or docker-ce installed in WSL2); on macOS/Linux, Docker Engine (or Desktop) is fine.
- Nothing else for the lakes: no `.env` file, no cloud accounts. All
  credentials are hardcoded dev defaults (do NOT use in production).
- To run the **Python** client: `python3` (3.10+). A venv is created below –
  never install system-wide.
- To run the **Java** client: JDK 17+ and Maven (`mvn -version`).

## Quickstart – macOS / Linux (bash)

```bash
# 0. clone and enter the repo
git clone <this-repo> && cd cm2027-ducklake

# 1. local lake: create + seed it
mkdir -p lakes/local/data   # so the ./data bind mount is host-owned, not root
docker compose -f lakes/local/compose.yaml up init

# 2. postgres + S3 lake: infra, bucket, then seed
cd lakes/local-pg-s3
docker compose up -d postgres garage
./scripts/garage-init.sh
docker compose run --rm seed
cd ../..

# 3a. python client (from the repo root)
python3 -m venv /tmp/ducklake-venv
/tmp/ducklake-venv/bin/pip install -r cmd/python-example/requirements.txt
/tmp/ducklake-venv/bin/python cmd/python-example/main.py            # local lake
/tmp/ducklake-venv/bin/python cmd/python-example/main.py --lake pg  # postgres+S3 lake

# 3b. java client (from the repo root; pick one)
mvn -f cmd/java-example/pom.xml exec:java -Dexec.args="--lake local"
mvn -f cmd/java-example/pom.xml exec:java -Dexec.args="--lake pg"
```

Each client attaches the lake, writes a check-in row, reads it back, and shows
`snapshots()` + time travel.

## Quickstart – Windows (PowerShell)

```powershell
# 0. clone and enter the repo
git clone <this-repo>; cd cm2027-ducklake

# 1. local lake: create + seed it
New-Item -ItemType Directory -Force lakes/local/data | Out-Null
docker compose -f lakes/local/compose.yaml up init

# 2. postgres + S3 lake: infra, bucket, then seed
cd lakes/local-pg-s3
docker compose up -d postgres garage
.\scripts\garage-init.ps1
docker compose run --rm seed
cd ..\..

# 3a. python client (from the repo root)
py -m venv $env:TEMP\ducklake-venv
$env:TEMP\ducklake-venv\Scripts\pip install -r cmd\python-example\requirements.txt
$env:TEMP\ducklake-venv\Scripts\python.exe cmd\python-example\main.py            # local lake
$env:TEMP\ducklake-venv\Scripts\python.exe cmd\python-example\main.py --lake pg  # postgres+S3 lake

# 3b. java client (from the repo root; pick one)
mvn -f cmd/java-example/pom.xml exec:java -Dexec.args="--lake local"
mvn -f cmd/java-example/pom.xml exec:java -Dexec.args="--lake pg"
```

> [!NOTE]
> Run the clients from the **repo root**: the default `--local-path`
> (`lakes/local/data/...`) resolves relative to where you run them.

## Details

Data paths, time travel, reset, and host-vs-container hostnames are in each
lake's `README.md` ([`lakes/local/`](lakes/local/),
[`lakes/local-pg-s3/`](lakes/local-pg-s3/)); client flags and venv notes are in
[`cmd/python-example/`](cmd/python-example/) and
[`cmd/java-example/`](cmd/java-example/).
