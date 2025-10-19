"""Celery app and background task skeletons for My Day."""
from __future__ import annotations

from celery import Celery

from . import config
from .database import session_scope
from .models import Entry, EntryStatus
import time
import uuid

def _download_to_temp(url: str) -> str:
    import tempfile
    import os
    import requests  # type: ignore

    attempts = 0
    backoff = 1.0
    last_exc = None
    while attempts < config.AUDIO_MAX_RETRIES:
        attempts += 1
        try:
            fd, path = tempfile.mkstemp(suffix=".m4a")
            written = 0
            with os.fdopen(fd, "wb") as f:
                with requests.get(url, stream=True, timeout=config.AUDIO_TIMEOUT_SECONDS) as r:
                    r.raise_for_status()
                    for chunk in r.iter_content(chunk_size=1024 * 64):
                        if not chunk:
                            continue
                        written += len(chunk)
                        if written > config.AUDIO_MAX_BYTES:
                            raise ValueError("Audio exceeds maximum allowed size")
                        f.write(chunk)
            return path
        except Exception as e:  # retry on any error
            last_exc = e
            time.sleep(backoff)
            backoff = min(backoff * 2, 8)
        finally:
            # If failed, remove partial file
            try:
                if 'path' in locals() and last_exc is not None:
                    os.remove(path)
            except OSError:
                pass
    # Exhausted retries
    if last_exc:
        raise last_exc
    raise RuntimeError("Failed to download audio")


def _whisper_transcribe(audio_url: str) -> str:
    try:
        from faster_whisper import WhisperModel  # type: ignore
    except Exception:
        # Fallback when dependency is missing
        return "[transcription unavailable: faster-whisper not installed]"

    audio_path = _download_to_temp(audio_url)
    try:
        model = WhisperModel(config.WHISPER_MODEL, device=config.WHISPER_DEVICE)
        segments, _info = model.transcribe(audio_path)
        text_parts = [seg.text for seg in segments]
        return " ".join(t.strip() for t in text_parts if t and t.strip()) or ""
    finally:
        import os
        try:
            os.remove(audio_path)
        except OSError:
            pass


def _cleanup_with_llm(text: str) -> str:
    if not text or config.LLM_PROVIDER.lower() == "none":
        return text
    provider = config.LLM_PROVIDER.lower()
    if provider == "openai" and config.LLM_API_KEY:
        import requests  # type: ignore
        headers = {
            "Authorization": f"Bearer {config.LLM_API_KEY}",
            "Content-Type": "application/json",
        }
        prompt = (
            "You are a helpful assistant. Clean up the given transcript: "
            "remove filler words, add punctuation, and format into clear paragraphs."
        )
        payload = {
            "model": config.LLM_MODEL,
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
            "temperature": 0.2,
        }
        try:
            resp = requests.post(config.LLM_ENDPOINT, json=payload, headers=headers, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            # OpenAI-style response
            content = data.get("choices", [{}])[0].get("message", {}).get("content")
            if isinstance(content, str) and content.strip():
                return content.strip()
        except Exception:
            # Fallback to raw text on any error
            return text
    # Unknown provider or missing key
    return text


celery_app = Celery(
    "myday",
    broker=config.BROKER_URL,
    backend=config.RESULT_BACKEND,
)


@celery_app.task(name="transcribe_entry")
def transcribe_entry(entry_id: int, idempotency_key: str | None = None) -> dict:
    """Placeholder transcription task.

    In production, this should download the audio from storage, run ASR
    (e.g., faster-whisper), then run an LLM cleanup pass and update the DB.

    For now, we mark the entry as transcribed with stub text if it exists.
    """
    with session_scope() as session:
        entry = session.get(Entry, entry_id)
        if not entry:
            return {"ok": False, "reason": "not_found", "entry_id": entry_id}
        # Idempotency: skip if already processed
        if entry.status == EntryStatus.TRANSCRIBED:
            return {"ok": True, "entry_id": entry_id, "status": entry.status, "idempotent": True}

        # Record idempotency key if provided, and ignore duplicate invocations
        if idempotency_key:
            if entry.idempotency_key and entry.idempotency_key == idempotency_key:
                return {"ok": True, "entry_id": entry_id, "status": entry.status, "idempotent": True}
            if not entry.idempotency_key:
                entry.idempotency_key = idempotency_key

        try:
            if config.TRANSCRIPTION_BACKEND.lower() == "whisper" and entry.audio_url:
                text = _whisper_transcribe(entry.audio_url)
                entry.transcript_raw = text or entry.transcript_raw
                cleaned = _cleanup_with_llm(entry.transcript_raw or "")
                entry.transcript_clean = entry.transcript_clean or (cleaned.strip() if cleaned else None)
                entry.status = EntryStatus.TRANSCRIBED
            else:
                entry.transcript_raw = entry.transcript_raw or "[raw transcript placeholder]"
                cleaned = _cleanup_with_llm(entry.transcript_raw)
                entry.transcript_clean = entry.transcript_clean or cleaned
                entry.status = EntryStatus.TRANSCRIBED
            entry.failure_reason = None
        except Exception as e:
            entry.status = EntryStatus.FAILED
            # Truncate failure reason to avoid huge blobs
            entry.failure_reason = (str(e) or e.__class__.__name__)[:1000]
        finally:
            session.add(entry)
            session.commit()
            session.refresh(entry)
        return {"ok": entry.status == EntryStatus.TRANSCRIBED, "entry_id": entry_id, "status": entry.status}
