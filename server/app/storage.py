"""Storage utilities for generating upload URLs and public object URLs.

Supports a no-op placeholder mode and S3-compatible backends (AWS/MinIO).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from . import config


def _timestamped_filename(suffix: str = "m4a", uid: Optional[str] = None) -> str:
    now = datetime.now(timezone.utc)
    ts = now.strftime("%Y-%m-%d_%H-%M-%S")
    short = uid or uuid.uuid4().hex[:8]
    return f"{ts}_{short}.{suffix}"


def generate_object_key(user_id: int, suffix: str = "m4a") -> str:
    """Generate object key using convention users/{id}/YYYY-MM-DD_HH-mm-ss_uuid8.m4a"""
    fname = _timestamped_filename(suffix=suffix)
    return f"users/{user_id}/{fname}"


def generate_upload_url(object_key: str, content_type: str = "audio/m4a", expires_in: int = 3600) -> str:
    """Return a signed URL for uploading the object content.

    For placeholder backend, return a deterministic fake URL.
    For S3 backend, return a presigned PUT URL.
    """
    if config.STORAGE_BACKEND.lower() != "s3":
        # Placeholder URL that still ends with .m4a for tests
        base = "https://uploads.example.com"
        return f"{base}/{object_key}"

    # Lazily import boto3 to avoid dependency when not using S3
    import boto3  # type: ignore

    client = boto3.client(
        "s3",
        endpoint_url=config.S3_ENDPOINT_URL,
        region_name=config.S3_REGION_NAME,
        aws_access_key_id=config.S3_ACCESS_KEY_ID,
        aws_secret_access_key=config.S3_SECRET_ACCESS_KEY,
    )
    params = {
        "Bucket": config.S3_BUCKET,
        "Key": object_key,
        "ContentType": content_type,
    }
    return client.generate_presigned_url(
        ClientMethod="put_object",
        Params=params,
        ExpiresIn=expires_in,
    )


def object_public_url(object_key: str) -> str:
    """Return a public URL to access the object (if exposed), or the S3 path.

    If `MYDAY_S3_PUBLIC_BASE_URL` is provided, use that as a base; otherwise
    return a conventional S3 URL.
    """
    if config.STORAGE_BACKEND.lower() != "s3":
        return f"https://cdn.example.com/{object_key}"

    if config.S3_PUBLIC_BASE_URL:
        return f"{config.S3_PUBLIC_BASE_URL.rstrip('/')}/{object_key}"

    # Fallback S3-style URL (may require proper bucket policy)
    endpoint = (config.S3_ENDPOINT_URL or "https://s3.amazonaws.com").rstrip("/")
    return f"{endpoint}/{config.S3_BUCKET}/{object_key}"


def object_exists(object_key: str) -> bool:
    """Return True if the object exists in storage.

    - placeholder backend: always True
    - s3 backend: HEAD the object
    """
    if config.STORAGE_BACKEND.lower() != "s3":
        return True

    import boto3  # type: ignore
    from botocore.exceptions import ClientError  # type: ignore

    client = boto3.client(
        "s3",
        endpoint_url=config.S3_ENDPOINT_URL,
        region_name=config.S3_REGION_NAME,
        aws_access_key_id=config.S3_ACCESS_KEY_ID,
        aws_secret_access_key=config.S3_SECRET_ACCESS_KEY,
    )
    try:
        client.head_object(Bucket=config.S3_BUCKET, Key=object_key)
        return True
    except ClientError:
        return False


def upload_file(object_key: str, local_path: str, content_type: str = "application/octet-stream") -> str:
    """Upload a local file to storage under object_key and return its public URL.

    - placeholder backend: pretends upload succeeded and returns a CDN URL.
    - s3 backend: uses boto3 to upload the file then returns public URL.
    """
    if config.STORAGE_BACKEND.lower() != "s3":
        return f"https://cdn.example.com/{object_key}"

    import boto3  # type: ignore

    client = boto3.client(
        "s3",
        endpoint_url=config.S3_ENDPOINT_URL,
        region_name=config.S3_REGION_NAME,
        aws_access_key_id=config.S3_ACCESS_KEY_ID,
        aws_secret_access_key=config.S3_SECRET_ACCESS_KEY,
    )
    client.upload_file(local_path, config.S3_BUCKET, object_key, ExtraArgs={"ContentType": content_type})
    return object_public_url(object_key)
