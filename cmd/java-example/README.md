# Java example (DuckLake client)

Minimal client: attach a lake, insert a row, read it back, show snapshots and
time travel. Works against both lakes in this repo. Same demo as
[`../python-example/`](../python-example/). Upstream JDBC reference is available [here](https://duckdb.org/docs/current/clients/java/overview).

## Prerequisites

- JDK 17+ and Maven (see [`mvn -version`](https://maven.apache.org/))
- Docker + Compose for the lakes themselves

## Run: local lake

From the **repo root** (seed first):

```bash
docker compose -f lakes/local/compose.yaml up init
mvn -f cmd/java-example/pom.xml exec:java -Dexec.args="--lake local"
```

The default `--local-path` (`lakes/local/data/...`) resolves relative to where
you run Maven, hence repo root. The app passes `OVERRIDE_DATA_PATH`
automatically, see [`lakes/local/README.md`](../../lakes/local/README.md).

## Run: Postgres + S3 lake

From `lakes/local-pg-s3` (infra + bucket first, no `.env` needed):

```bash
docker compose up -d postgres garage
./scripts/garage-init.sh        # or .\scripts\garage-init.ps1 on Windows
mvn -f ../../cmd/java-example/pom.xml exec:java -Dexec.args="--lake pg"
```

## Flags

Just `--lake local|pg` (default `local`) and `--local-path`
(default `lakes/local/data/my_ducklake.ducklake`, relative to where you run
Maven). S3/Postgres credentials are hardcoded dev defaults in `App.java`
matching the lakes; edit the constants there if you changed them.

## Note

On recent JDKs (tested with 26) DuckDB prints a
`--enable-native-access=ALL-UNNAMED` warning. Harmless; silence it with e.g.
`MAVEN_OPTS="--enable-native-access=ALL-UNNAMED" mvn ...`.
