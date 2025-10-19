"""Configuration settings for My Day API.

Values are read from environment variables with safe defaults for local dev.
Do not hardcode secrets in production.
"""
from __future__ import annotations

import os
from datetime import timedelta


def _get_env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


# Core
APP_NAME = os.getenv("MYDAY_APP_NAME", "My Day API")
APP_VERSION = os.getenv("MYDAY_APP_VERSION", "0.1.0")

# Security
SECRET_KEY = _get_env("MYDAY_SECRET_KEY", "myday-secret")
ALGORITHM = os.getenv("MYDAY_JWT_ALGORITHM", "HS256")
TOKEN_EXPIRY_MINUTES = int(os.getenv("MYDAY_TOKEN_EXPIRY_MINUTES", "60"))

# Database
DATABASE_URL = os.getenv("MYDAY_DATABASE_URL", "sqlite:///./myday_dev.db")


def access_token_expires_delta() -> timedelta:
    return timedelta(minutes=TOKEN_EXPIRY_MINUTES)

# Storage
STORAGE_BACKEND = os.getenv("MYDAY_STORAGE_BACKEND", "placeholder")  # one of: placeholder, s3

# S3 settings (used when STORAGE_BACKEND == 's3')
S3_ENDPOINT_URL = os.getenv("MYDAY_S3_ENDPOINT_URL")  # e.g., http://localhost:9000 for MinIO
S3_REGION_NAME = os.getenv("MYDAY_S3_REGION", "us-east-1")
S3_ACCESS_KEY_ID = os.getenv("MYDAY_S3_ACCESS_KEY_ID")
S3_SECRET_ACCESS_KEY = os.getenv("MYDAY_S3_SECRET_ACCESS_KEY")
S3_BUCKET = os.getenv("MYDAY_S3_BUCKET", "myday-dev")
S3_PUBLIC_BASE_URL = os.getenv("MYDAY_S3_PUBLIC_BASE_URL")  # optional CDN/base URL


def _get_bool(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


# Upload verification (S3 head_object) during finalize
VERIFY_UPLOADS = _get_bool("MYDAY_VERIFY_UPLOADS", "false")

# Background processing (Celery)
BROKER_URL = os.getenv("MYDAY_BROKER_URL", "redis://redis:6379/0")
RESULT_BACKEND = os.getenv("MYDAY_RESULT_BACKEND", "redis://redis:6379/1")
AUTO_ENQUEUE_TRANSCRIPTION = _get_bool("MYDAY_AUTO_ENQUEUE_TRANSCRIPTION", "false")

# Transcription backend
TRANSCRIPTION_BACKEND = os.getenv("MYDAY_TRANSCRIPTION_BACKEND", "stub")  # stub|whisper
WHISPER_MODEL = os.getenv("MYDAY_WHISPER_MODEL", "tiny")
WHISPER_DEVICE = os.getenv("MYDAY_WHISPER_DEVICE", "cpu")

# Audio fetch limits
AUDIO_TIMEOUT_SECONDS = int(os.getenv("MYDAY_AUDIO_TIMEOUT_SECONDS", "30"))
AUDIO_MAX_RETRIES = int(os.getenv("MYDAY_AUDIO_MAX_RETRIES", "3"))
AUDIO_MAX_BYTES = int(os.getenv("MYDAY_AUDIO_MAX_BYTES", str(50 * 1024 * 1024)))  # 50 MB

# LLM cleanup
LLM_PROVIDER = os.getenv("MYDAY_LLM_PROVIDER", "none")  # none|openai
LLM_MODEL = os.getenv("MYDAY_LLM_MODEL", "gpt-4o-mini")
LLM_API_KEY = os.getenv("MYDAY_LLM_API_KEY")
LLM_ENDPOINT = os.getenv("MYDAY_LLM_ENDPOINT", "https://api.openai.com/v1/chat/completions")

# Export generation
EXPORT_SYNC = _get_bool("MYDAY_EXPORT_SYNC", "true")
