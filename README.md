# BionicDB

An API — with a web frontend and an MCP server — to download and inspect the
Bionic `libc` versions shipped across Android platforms. Given a libc GNU build
ID you can fetch the matching `libc.so`, look up a symbol's offset, or find which
builds place a symbol at a given offset.

> **Demo:** <https://www.cs.purdue.edu/homes/antoniob/bionicdb.html>. This is a
> **demo** deployment — treat it as temporary; the underlying instance's domain
> may change later.

## What's in the box

- `api/` — a FastAPI service (`app.main:app`), a static web frontend
  (`api/static/`), and a read-only MCP server (`app.mcp_server`).
- `bionic.db` — a SQLite index of libc builds, their releases (device / Android
  version / API level / security patch), and exported symbol offsets.
- `objects/` — the libc binaries themselves, stored as `objects/<xx>/<sha256>.so`.
  There are ~150 files totalling ~150 MiB, so they are **not tracked individually
  in git**; they ship compressed as `objects.tar.xz` and are unpacked at deploy
  time.

## Quick start (local website)

From a fresh checkout:

```sh
./deploy.sh
```

This unpacks the libc dataset from `objects.tar.xz` (~150 MiB once expanded) and
then builds and serves the site with Docker. Once it is up:

- Web frontend — <http://localhost:8000/>
- API docs (Swagger UI) — <http://localhost:8000/docs>

Use `BIONICDB_PORT=9000 ./deploy.sh` for a different port, or
`./deploy.sh --unpack-only` to expand the dataset without starting anything.

## The libc dataset

The `objects/<xx>/<sha256>.so` blobs are required by the file-download endpoint
and the MCP `get_library_file` tool; the metadata endpoints work from `bionic.db`
alone. `deploy.sh` unpacks them for you, but you can also do it by hand:

```sh
tar -xJf objects.tar.xz          # populates objects/<xx>/<sha256>.so
```

The extracted `.so` files stay git-ignored (see `objects/.gitignore`); the
compressed `objects.tar.xz` is the tracked source of truth and is kept as an
`.xz` to keep the repository small.

`objects.tar.xz` is just an xz-compressed archive of the `objects/` tree — the
content-addressed libc store (`objects/<xx>/<sha256>.so`) that `bionic.db`
indexes. After changing the dataset, re-create it from the repository root with
`tar -cJf objects.tar.xz objects`.

## Run without Docker

Unpack the dataset once, then use [`uv`](https://docs.astral.sh/uv/):

```sh
tar -xJf objects.tar.xz
cd api && uv run uvicorn app.main:app        # add --reload for development
```

The API is served at <http://127.0.0.1:8000>. It opens `bionic.db` from the
repository root read-only; override the location with
`BIONIC_DB_PATH=/path/to/bionic.db`.

## Run with Docker directly

`deploy.sh` calls these under the hood; you can also run them yourself **after
unpacking the dataset** (`tar -xJf objects.tar.xz`):

```sh
docker compose up --build        # or: docker-compose up --build
```

## API

- `GET /v1/libs` — list indexed libc builds with device/release metadata.
- `GET /v1/libs/{build_id}` — download the matching `libc.so`.
- `GET /v1/libs/{build_id}/offset?symbol=NAME` — resolve a symbol's offset in that build.
- `GET /v1/symbol/matches?offset=0x1234&symbol=NAME` — find builds where a symbol sits at a given offset.

## MCP server

A read-only MCP server exposes `list_builds`, `find_libraries`,
`find_symbol_offset`, and `get_library_file` over stdio:

```sh
cd api && uv run python -m app.mcp_server
```

See [`api/README.md`](api/README.md) for `uv` setup, an example MCP client
configuration, and how to run the tests.
