"""Integration tests for the My Day API scaffold."""
from datetime import datetime, timedelta

from fastapi.testclient import TestClient

from server.app.main import app

client = TestClient(app)


def _auth(email: str = "demo@example.com"):
    resp = client.post("/v1/auth/email", json={"email": email})
    assert resp.status_code == 200
    data = resp.json()
    token = data["access_token"]
    user_id = data["user_id"]
    headers = {"Authorization": f"Bearer {token}"}
    return headers, user_id


def test_email_auth_creates_user_and_returns_token() -> None:
    response = client.post("/v1/auth/email", json={"email": "demo@example.com"})
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user_id"] > 0


def test_create_and_fetch_entry() -> None:
    headers, user_id = _auth("entry@example.com")

    response = client.post(
        "/v1/entries",
        json={"user_id": user_id, "duration_s": 120, "size_bytes": 1024},
        headers=headers,
    )
    assert response.status_code == 201
    payload = response.json()
    assert payload["upload_url"].endswith(".m4a")
    assert payload["object_key"].endswith(".m4a")

    entry_id = payload["entry_id"]
    detail_response = client.get(f"/v1/entries/{entry_id}", headers=headers)
    assert detail_response.status_code == 200
    detail = detail_response.json()
    assert detail["duration_s"] == 120


def test_finalize_upload_sets_audio_url() -> None:
    headers, user_id = _auth("finalize@example.com")
    # Create entry and get object_key
    create = client.post(
        "/v1/entries",
        json={"user_id": user_id, "duration_s": 10},
        headers=headers,
    )
    assert create.status_code == 201
    body = create.json()
    eid = body["entry_id"]
    object_key = body["object_key"]

    # Finalize upload
    fin = client.post(
        f"/v1/entries/{eid}/finalize",
        json={"object_key": object_key, "size_bytes": 2048},
        headers=headers,
    )
    assert fin.status_code == 200
    data = fin.json()
    assert data["audio_url"].endswith(".m4a")
    assert data["size_bytes"] == 2048


def test_transcribe_endpoint_smoke() -> None:
    headers, user_id = _auth("transcribe-smoke@example.com")
    # Create and finalize to set processing
    create = client.post(
        "/v1/entries",
        json={"user_id": user_id, "duration_s": 5},
        headers=headers,
    )
    assert create.status_code == 201
    body = create.json()
    eid = body["entry_id"]
    object_key = body["object_key"]

    fin = client.post(
        f"/v1/entries/{eid}/finalize",
        json={"object_key": object_key},
        headers=headers,
    )
    assert fin.status_code == 200
    assert fin.json()["status"] in ("processing", "transcribed")

    # Re-enqueue transcription
    tr = client.post(f"/v1/entries/{eid}/transcribe", json={}, headers=headers)
    assert tr.status_code == 200
    assert tr.json()["status"] in ("processing", "transcribed")


def test_list_entries_since_filter() -> None:
    headers, _ = _auth("list-since@example.com")
    cutoff = (datetime.utcnow() - timedelta(days=1)).isoformat()
    response = client.get(f"/v1/entries?since={cutoff}", headers=headers)
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_update_entry_status_and_transcripts() -> None:
    headers, user_id = _auth("update@example.com")

    create_resp = client.post(
        "/v1/entries",
        json={"user_id": user_id, "duration_s": 30},
        headers=headers,
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
        headers=headers,
    )
    assert update_resp.status_code == 200
    payload = update_resp.json()
    assert payload["status"] == "transcribed"
    assert payload["audio_url"].endswith("audio.m4a")
    assert payload["transcript_clean"] == "Clean text."
    assert payload["transcript_raw"] == "raw text"


def test_entries_pagination_and_status_filter() -> None:
    headers, user_id = _auth("paginate@example.com")
    # Create 3 entries
    for d in (10, 20, 30):
        r = client.post("/v1/entries", json={"user_id": user_id, "duration_s": d}, headers=headers)
        assert r.status_code == 201
    # Update one to transcribed
    # Get newest entry id by fetching with limit=1
    newest = client.get("/v1/entries", params={"limit": 1}, headers=headers)
    assert newest.status_code == 200
    latest_id = newest.json()[0]["id"]
    upd = client.patch(
        f"/v1/entries/{latest_id}",
        json={"status": "transcribed", "transcript_clean": "ok"},
        headers=headers,
    )
    assert upd.status_code == 200

    # Pagination: limit 2 returns 2 items
    page = client.get("/v1/entries", params={"limit": 2}, headers=headers)
    assert page.status_code == 200
    assert len(page.json()) == 2

    # Offset should skip first item
    page2 = client.get("/v1/entries", params={"limit": 2, "offset": 1}, headers=headers)
    assert page2.status_code == 200
    assert len(page2.json()) >= 1

    # Status filter should return at least the updated one
    trans = client.get("/v1/entries", params={"status": "transcribed"}, headers=headers)
    assert trans.status_code == 200
    assert any(item["id"] == latest_id for item in trans.json())


def test_entries_date_range_filter() -> None:
    headers, _ = _auth("daterange@example.com")
    # date_from set far in future should yield empty list
    future = (datetime.utcnow() + timedelta(days=365)).isoformat()
    res = client.get("/v1/entries", params={"date_from": future}, headers=headers)
    assert res.status_code == 200
    assert res.json() == []


def test_create_export_request() -> None:
    headers, user_id = _auth("exporter@example.com")

    now = datetime.utcnow()
    response = client.post(
        "/v1/exports",
        json={
            "user_id": user_id,
            "date_from": (now - timedelta(days=7)).isoformat(),
            "date_to": now.isoformat(),
            "email": "exporter@example.com",
        },
        headers=headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "complete"
    assert data["result_url"].endswith(".zip")

    fetch = client.get(f"/v1/exports/{data['id']}", headers=headers)
    assert fetch.status_code == 200


def test_list_exports() -> None:
    headers, user_id = _auth("list@example.com")

    now = datetime.utcnow()
    client.post(
        "/v1/exports",
        json={
            "user_id": user_id,
            "date_from": (now - timedelta(days=1)).isoformat(),
            "date_to": now.isoformat(),
            "email": "list@example.com",
        },
        headers=headers,
    )

    response = client.get("/v1/exports", params={"user_id": user_id}, headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert isinstance(body, list)
    assert body
