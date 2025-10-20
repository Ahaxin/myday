# My Day — Current MVP (iCloud‑Only)

This document supersedes the older server‑based plan. The current scope is an iOS‑only MVP that saves entries directly to iCloud via CloudKit.

## Scope
- Record audio notes and save them as CloudKit records (audio as CKAsset)
- Show a colorful, kid‑friendly list and detail view
- Playback with scrubber and last‑position resume
- Live refresh via CloudKit push subscription
- Local export to a shareable folder

## Non‑Goals (for now)
- Server‑side transcription and exports
- Third‑party auth (Apple/Google) and JWTs
- Web client and Docker deployment

## Follow‑ups
- Zip export folder
- Error surfaces for CloudKit failures
- Simple on‑device transcription (optional)
- Delete entry (with CloudKit record removal)
- Accessibility pass and localization

See README.md for setup and usage.

