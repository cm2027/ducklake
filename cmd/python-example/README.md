# Python example (DuckLake client)

Minimal client: attach a lake, insert a row, read it back, show snapshots and
time travel. Works against both lakes in this repo.

## Setup

bash/macOS/Linux:

```bash
cd cmd/python-example
python3 -m venv /tmp/ducklake-venv
/tmp/ducklake-venv/bin/pip install -r requirements.txt
```

Windows PowerShell:

```powershell
cd cmd/python-example
py -m venv $env:TEMP\ducklake-venv
$env:TEMP\ducklake-venv\Scripts\pip install -r requirements.txt
```

(Examples below use `/tmp/ducklake-venv/bin/python`; on Windows substitute
`$env:TEMP\ducklake-venv\Scripts\python.exe`.)

## Local lake

From the repo root (seed first):

```bash
docker compose -f lakes/local/compose.yaml up init
/tmp/ducklake-venv/bin/python cmd/python-example/main.py --lake local
```

Default `--local-path` is `lakes/local/data/my_ducklake.ducklake` (repo-root
relative). The script passes `OVERRIDE_DATA_PATH` automatically, see
[`lakes/local/README.md`](../../lakes/local/README.md).

## Postgres + S3 lake

From `lakes/local-pg-s3` (infra + bucket first, no `.env` needed):

```bash
docker compose up -d postgres garage
./scripts/garage-init.sh   # PowerShell: .\scripts\garage-init.ps1
/tmp/ducklake-venv/bin/python ../../cmd/python-example/main.py --lake pg
```

(`.env` / flags like `--s3-key` only override the hardcoded dev defaults.)

from the repo root equivalently:

```bash
/tmp/ducklake-venv/bin/python cmd/python-example/main.py --lake pg
```

Flags: just `--lake local|pg` (default `local`) and `--local-path`
(default `lakes/local/data/my_ducklake.ducklake`, repo-root relative).
S3/Postgres credentials are hardcoded dev defaults in `main.py` matching the
lakes; edit the constants there if you changed them.
