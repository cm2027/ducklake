# ducklake examples for cm2027

In this repository you will find examples for how to use a ducklake.

There are multiple different ways of running ducklake, this repo showcases two different ways:

- with duckdb as the meta store and the local filesystem for the raw storage (where the parquet files will live), see [`lakes/local/`](lakes/local/)
- with postgresql as the meta store and an s3 compatible object store as the raw storage, see [`lakes/local-pg-s3/`](lakes/local-pg-s3/)

> [!NOTE]
> s3 is an AWS service and costs, but there are several open source ones that have an compatible API.
> minio was the most used one for a while, but it has recently (last year) been deprecated and is unmaintained.
> Therefore we will use [`garage`](https://garagehq.deuxfleurs.fr/quick_start/index.html) for this example, which like minio is an open source s3 compatible object store.

## Prerequisites

- `docker` with `docker-compose` (bundled if you use [`docker-desktop`](https://www.docker.com/products/docker-desktop/)).
- To run the **Python** client: `python3` (3.10+).
- To run the **Java** client: JDK 17+.

## Quickstart

This quickstart will help you get started by setting up a ducklake in two different ways. The first example uses the local filesystem for the raw data and a duckdb for the metadata while then second one uses an s3 compatible object store for the raw data and an postgres database for the meta data.

### ducklake on local filesystem

```bash
docker compose -f lakes/local/compose.yaml up
```

#### Teardown

```bash
docker compose -f lakes/local/compose.yaml down
```

### ducklake on an object store + postgres for meta

```bash
docker compose -f lakes/local-pg-s3/compose.yaml up
```

#### Teardown

> [!NOTE]
> If you want to run the example clients, tear it down after running them, since they need to be able to access both postgres and s3.

```bash
docker compose -f lakes/local-pg-s3/compose.yaml down
# append -v to remove the data.
```

### Example clients

#### Python

To run the python example client, go into the [`./cmd/python-example/`](./cmd/python-example/) directory and create a virtual environment with your preferred method (venv/conda/etc...), for example with venv:

```bash
# in the ./cmd/python-example/ directory
python3 -m venv .venv
# Then activate it, on Linux / MacOS it is done with
# source .venv/bin/activate
```

Once in the virtual environment, download the dependencies:

```bash
# in the ./cmd/python-example/ directory with the virtual environment active
pip install -r requirements.txt
```

Then the client example can be run against a specified ducklake.

##### Running against the "local" ducklake

Make sure you have run the [initialization step for the ducklake on local filesystem example](#ducklake-on-local-filesystem).

```bash
# in the ./cmd/python-example/ directory with the virtual environment active
python3 ./main.py
# defaults to the "local" lake, where the data is stored on the local filesystem
```

##### Running against the ducklake that is using s3 and postgres

To be able to run this, make sure the docker compose (for the local-pg-s3 ducklake) is running, since the services need to be reachable by the client.

```bash
# in the ./cmd/python-example/ directory with the virtual environment active
python3 ./main.py --lake pg
```

#### Java

#### Running against the "local" ducklake

```bash
# in the ./cmd/java-example/ directory
./mvnw exec:java -Dexec.args="--lake local"
```

#### Running against the ducklake that is using s3 and postgres

To be able to run this, make sure the docker compose (for the local-pg-s3 ducklake) is running, since the services need to be reachable by the client.

```bash
# in the ./cmd/java-example/ directory
./mvnw exec:java -Dexec.args="--lake pg"
```
