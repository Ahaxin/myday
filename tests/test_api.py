"""Integration tests for the My Day API scaffold."""
from datetime import datetime, timedelta

from fastapi.testclient import TestClient

from server.app.main import app

client = TestClient(app)


def test_email_auth_creates_user_and_returns_token() -> None:
    response = client.post("/v1/auth/email", json={"email": "demo@example.com"})
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user_id"] > 0


def test_create_and_fetch_entry() -> None:
    # Ensure there is a user for the entry
    auth_response = client.post("/v1/auth/email", json={"email": "entry@example.com"})
    assert auth_response.status_code == 200
    user_id = auth_response.json()["user_id"]

    response = client.post(
        "/v1/entries",
        json={"user_id": user_id, "duration_s": 120, "size_bytes": 1024},
    )
    assert response.status_code == 201
    payload = response.json()
    assert payload["upload_url"].endswith(".m4a")

    entry_id = payload["entry_id"]
    detail_response = client.get(f"/v1/entries/{entry_id}")
    assert detail_response.status_code == 200
    detail = detail_response.json()
    assert detail["duration_s"] == 120


def test_list_entries_since_filter() -> None:
    cutoff = (datetime.utcnow() - timedelta(days=1)).isoformat()
    response = client.get(f"/v1/entries?since={cutoff}")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_update_entry_status_and_transcripts() -> None:
    auth_response = client.post("/v1/auth/email", json={"email": "update@example.com"})
    assert auth_response.status_code == 200
    user_id = auth_response.json()["user_id"]

    create_resp = client.post(
        "/v1/entries",
        json={"user_id": user_id, "duration_s": 30},
    )
    assert create_resp.status_code == 201
    entry_id = create_resp.json()["entry_id"]

    update_resp = client.patch(
        f"/v1/entries/{entry_id}",
        json={
            "status": "transcribed",
            "audio_url": "https://cdn.example.com/audio.m4a",
            "transcript_raw": "raw text",
            "transcript_clean": "Clean text.",
        },
    )
    assert update_resp.status_code == 200
    payload = update_resp.json()
    assert payload["status"] == "transcribed"
    assert payload["audio_url"].endswith("audio.m4a")
    assert payload["transcript_clean"] == "Clean text."
    assert payload["transcript_raw"] == "raw text"


def test_create_export_request() -> None:
    # reuse user from previous creation to keep database simple
    auth_response = client.post("/v1/auth/email", json={"email": "exporter@example.com"})
    assert auth_response.status_code == 200
    user_id = auth_response.json()["user_id"]

    now = datetime.utcnow()
    response = client.post(
        "/v1/exports",
        json={
            "user_id": user_id,
            "date_from": (now - timedelta(days=7)).isoformat(),
            "date_to": now.isoformat(),
            "email": "exporter@example.com",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "complete"
    assert data["result_url"].endswith(".zip")

    fetch = client.get(f"/v1/exports/{data['id']}")
    assert fetch.status_code == 200


def test_list_exports() -> None:
    auth_response = client.post("/v1/auth/email", json={"email": "list@example.com"})
    assert auth_response.status_code == 200
    user_id = auth_response.json()["user_id"]

    now = datetime.utcnow()
    client.post(
        "/v1/exports",
        json={
            "user_id": user_id,
            "date_from": (now - timedelta(days=1)).isoformat(),
            "date_to": now.isoformat(),
            "email": "list@example.com",
        },
    )

    response = client.get("/v1/exports", params={"user_id": user_id})
    assert response.status_code == 200
    body = response.json()
    assert isinstance(body, list)
    assert body
