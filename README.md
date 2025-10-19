# My Day API

A FastAPI backend for the My Day iOS app. It supports audio diary entries, background transcription, and export bundles, with authentication, Postgres/SQLite storage, S3-compatible object storage, and Celery workers.

## Features
- JWT auth via email bootstrap (placeholder for Apple/Google).
- Entries: create, list (with filters + pagination), update, finalize upload, re-enqueue transcription.
- Transcription pipeline: Whisper (CPU/GPU) with robust fetch, idempotency, and optional LLM cleanup.
- Exports: build ZIPs of audio + cleaned transcripts and upload to S3/MinIO.
- Config via environment variables; Docker Compose for local stack (API, Postgres, Redis, MinIO, worker).
- Alembic migrations for Postgres; SQLite for quick dev/tests.
- Tests with `pytest` (all pass).

## Stack
- API: FastAPI + SQLModel
- DB: Postgres (prod) / SQLite (dev/tests)
- Queue: Celery + Redis
- Storage: S3-compatible (MinIO locally)
- Transcription: faster-whisper (optional) with ffmpeg
- Optional LLM cleanup: OpenAI-compatible endpoint

## Repo Layout
- `server/app/main.py` FastAPI app factory
- `server/app/routes/` `auth`, `entries`, `exports`
- `server/app/models.py` SQLModel entities and status enums
- `server/app/security.py` JWT dependency
- `server/app/database.py` engine + session helpers
- `server/app/storage.py` presign, existence check, upload helper
- `server/app/tasks.py` Celery app with transcription + export tasks
- `alembic/` migrations and config
- `docker-compose.yml`, `Dockerfile` (API), `Dockerfile.worker` (CPU), `Dockerfile.worker.gpu` (CUDA)
- `tests/test_api.py` integration tests

## Quick Start (Docker Compose)
1. Build and start the stack:
   - `docker compose up --build`
2. Services:
   - API: `http://localhost:8000`
   - MinIO (S3) console: `http://localhost:9001` (user/pass: `minioadmin`/`minioadmin`)
   - Postgres: `localhost:5432` (db/user/pass: `myday`/`myday`/`myday`)
3. Migrations are applied automatically by the API entrypoint.
4. By default, exports run synchronously in the API (`MYDAY_EXPORT_SYNC=true`). Set to `false` to enqueue via Celery.
5. The CPU worker runs with Whisper enabled. For GPU, start the `worker-gpu` service (requires NVIDIA runtime).

## Quick Start (Local Dev)
- Python 3.11 recommended.
- Install deps and run tests:
  - `python -m pip install -r requirements.txt`
  - `python -m pytest -q`
- Run the API locally (SQLite):
  - `uvicorn server.app.main:app --reload`
- Set `MYDAY_DATABASE_URL` to Postgres and run migrations:
  - `alembic upgrade head`

## Environment Variables (key ones)
- App: `MYDAY_SECRET_KEY`, `MYDAY_APP_NAME`, `MYDAY_APP_VERSION`
- DB: `MYDAY_DATABASE_URL` (default `sqlite:///./myday_dev.db`)
- Storage: `MYDAY_STORAGE_BACKEND=placeholder|s3`, `MYDAY_S3_ENDPOINT_URL`, `MYDAY_S3_REGION`, `MYDAY_S3_ACCESS_KEY_ID`, `MYDAY_S3_SECRET_ACCESS_KEY`, `MYDAY_S3_BUCKET`, `MYDAY_S3_PUBLIC_BASE_URL`
- Upload verify: `MYDAY_VERIFY_UPLOADS=true|false`
- Celery: `MYDAY_BROKER_URL`, `MYDAY_RESULT_BACKEND`, `MYDAY_AUTO_ENQUEUE_TRANSCRIPTION`
- Transcription: `MYDAY_TRANSCRIPTION_BACKEND=stub|whisper`, `MYDAY_WHISPER_MODEL`, `MYDAY_WHISPER_DEVICE=cpu|cuda`
- Audio fetch limits: `MYDAY_AUDIO_TIMEOUT_SECONDS`, `MYDAY_AUDIO_MAX_RETRIES`, `MYDAY_AUDIO_MAX_BYTES`
- LLM cleanup: `MYDAY_LLM_PROVIDER=none|openai`, `MYDAY_LLM_API_KEY`, `MYDAY_LLM_MODEL`, `MYDAY_LLM_ENDPOINT`
- Exports: `MYDAY_EXPORT_SYNC=true|false`

## Authentication
- Email-based bootstrap: `POST /v1/auth/email {"email":"you@example.com"}`
- The response contains `access_token` (JWT). Use as `Authorization: Bearer <token>` for other endpoints.

## Entries API (high level)
- `POST /v1/entries` create entry (client-side record metadata), returns `entry_id`, `upload_url`, `object_key`.
- Client uploads audio to `upload_url`, then calls finalize:
- `POST /v1/entries/{entry_id}/finalize` with `{ "object_key": "..." }` to set `audio_url`, set `status=processing`, generate an idempotency key, and enqueue transcription.
- `POST /v1/entries/{entry_id}/transcribe` to (re)enqueue transcription; optional `idempotency_key` to dedupe.
- `PATCH /v1/entries/{entry_id}` background updates (status, transcripts, etc.) if needed.
- `GET /v1/entries` list entries for current user with filters:
  - `since`, `status`, `date_from`, `date_to`, `limit` (1–100, default 50), `offset` (>=0)
- `GET /v1/entries/{entry_id}` fetch single entry.

Statuses: `uploaded`, `processing`, `transcribed`, `failed`. On errors, entries include `failure_reason` when applicable.

## Exports API
- `POST /v1/exports` create export request for a date range; marks `processing`, then generates ZIP.
- Dev default runs sync (`MYDAY_EXPORT_SYNC=true`), otherwise enqueues Celery task.
- `GET /v1/exports` list past export requests for the user.
- `GET /v1/exports/{id}` fetch one export request (includes `result_url` on completion).

ZIP contents per entry:
- `YYYY-MM-DD_HH-MM-SS.m4a` (best effort; skipped on fetch failure)
- `YYYY-MM-DD_HH-MM-SS.txt` (cleaned transcript when available)

## Transcription Pipeline
- Backend: `stub` (no ASR) or `whisper` (faster-whisper).
- Robust audio fetch: retries with exponential backoff, timeout, max size cap.
- Idempotency: tasks accept `idempotency_key` to dedupe; entries store the key and current status.
- Optional LLM cleanup (e.g., OpenAI) to tidy transcripts into clean paragraphs.
- GPU: use `worker-gpu` (CUDA) service; CPU fallback with `worker` service.

## Migrations
- For Postgres, manage schema with Alembic:
  - `alembic upgrade head`
  - Generate new migrations with `alembic revision --autogenerate -m "message"`
- For SQLite dev/tests, tables are auto-created.

## Running Tests
- `python -m pytest -q`

## cURL Examples
- Authenticate:
  - `curl -sX POST http://localhost:8000/v1/auth/email -H 'Content-Type: application/json' -d '{"email":"me@example.com"}'`
- Create entry:
  - `curl -sX POST http://localhost:8000/v1/entries -H 'Authorization: Bearer <token>' -H 'Content-Type: application/json' -d '{"user_id":1, "duration_s":60}'`
- Finalize upload:
  - `curl -sX POST http://localhost:8000/v1/entries/1/finalize -H 'Authorization: Bearer <token>' -H 'Content-Type: application/json' -d '{"object_key":"users/1/2024-01-01_00-00-00_abcd1234.m4a"}'`
- Create export:
  - `curl -sX POST http://localhost:8000/v1/exports -H 'Authorization: Bearer <token>' -H 'Content-Type: application/json' -d '{"user_id":1, "date_from":"2024-01-01T00:00:00Z", "date_to":"2024-12-31T23:59:59Z", "email":"me@example.com"}'`

## Notes
- This is an MVP scaffold suitable for development and early integration. Hardening items for production include: token rotation and third-party auth verification, stricter validation and limits, rate limiting, audit logs, comprehensive observability, and secrets management.

