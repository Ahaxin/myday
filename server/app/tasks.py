"""Celery app and background task skeletons for My Day."""
from __future__ import annotations

from celery import Celery

from . import config
from .database import session_scope
from .models import Entry, EntryStatus, ExportRequest, ExportStatus
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


@celery_app.task(name="generate_export")
def generate_export(export_id: int) -> dict:
    """Create a zip containing audio and cleaned transcripts for an export request.

    On success, uploads zip to storage and marks EXPORT as COMPLETE with result_url.
    On failure, marks as FAILED with failure reason retained in DB via status only.
    """
    import io
    import zipfile
    from datetime import timezone
    from .storage import upload_file, object_public_url
    import requests  # type: ignore

    with session_scope() as session:
        export = session.get(ExportRequest, export_id)
        if not export:
            return {"ok": False, "reason": "not_found", "export_id": export_id}

        export.status = ExportStatus.PROCESSING
        session.add(export)
        session.commit()

        # Gather entries
        from sqlmodel import select
        statement = (
            select(Entry)
            .where(Entry.user_id == export.user_id)
            .where(Entry.created_at >= export.date_from)
            .where(Entry.created_at <= export.date_to)
            .order_by(Entry.created_at.asc())
        )
        entries = session.exec(statement).all()

        # Build zip in temp file
        import tempfile
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        tmp_path = tmp.name
        tmp.close()

        def fname_base(dt):
            ts = dt.replace(tzinfo=timezone.utc).strftime("%Y-%m-%d_%H-%M-%S")
            return ts

        try:
            with zipfile.ZipFile(tmp_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
                for e in entries:
                    base = fname_base(e.created_at)
                    # Transcript file
                    if e.transcript_clean:
                        zf.writestr(f"{base}.txt", e.transcript_clean)
                    # Audio file (best-effort download)
                    if e.audio_url:
                        try:
                            with requests.get(e.audio_url, stream=True, timeout=10) as r:
                                r.raise_for_status()
                                data = io.BytesIO(r.content)
                                zf.writestr(f"{base}.m4a", data.getvalue())
                        except Exception:
                            # Skip audio on failure; continue building zip
                            pass

            # Upload zip
            object_key = f"exports/{export.user_id}/{export.id}.zip"
            download_url = upload_file(object_key, tmp_path, content_type="application/zip")

            export.status = ExportStatus.COMPLETE
            export.result_url = download_url or object_public_url(object_key)
            session.add(export)
            session.commit()
            session.refresh(export)
            return {"ok": True, "export_id": export.id, "status": export.status}
        except Exception as e:
            export.status = ExportStatus.FAILED
            session.add(export)
            session.commit()
            return {"ok": False, "export_id": export.id, "status": export.status, "error": str(e)[:500]}
        finally:
            import os
            try:
                os.remove(tmp_path)
            except OSError:
                pass
