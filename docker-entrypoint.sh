#!/bin/sh
set -e

# Run DB migrations
echo "Running Alembic migrations..."
alembic upgrade head

echo "Starting API server..."
exec uvicorn server.app.main:app --host 0.0.0.0 --port 8000

