# Xcode + CloudKit Setup Checklist

Use this quick checklist to get the iCloud‑only My Day app running on device and validate the CloudKit schema.

## Prerequisites
- Apple Developer team access (enabled for iCloud + Push Notifications)
- Unique bundle identifier (e.g., `com.yourdomain.myday`)
- Physical iOS device signed into iCloud (recommended for CloudKit + push)

## Xcode Capabilities
- iCloud
  - Enable “iCloud” and check “CloudKit”.
  - Select or create your container (e.g., `iCloud.com.yourdomain.myday`).
- Push Notifications
  - Enable “Push Notifications”.
- Background Modes
  - Enable “Background Modes” → check “Remote notifications”.

## Signing
- Targets → Signing & Capabilities
  - Select your “Team” and keep “Automatically manage signing” enabled.
  - Ensure the provisioning profile includes iCloud + Push entitlements.

## Info.plist
- Add key: `NSMicrophoneUsageDescription`
  - Value suggestion: “This app records audio to save your diary entry.”

## Entitlements (auto‑managed by Xcode when capabilities are enabled)
- `com.apple.developer.icloud-container-identifiers` → includes your container
- `com.apple.developer.icloud-services` → `CloudKit`
- `aps-environment` → `development` (Debug) / `production` (Release/TestFlight)

## CloudKit Dashboard (https://icloud.developer.apple.com/dashboard)
- Environment: Development
- Database: Private Database
- Record Types
  - Create `Entry` with fields:
    - `id` (String)
    - `createdAt` (Date)
    - `duration` (Double)
    - `sizeBytes` (Int/Int64)
    - `status` (String: uploaded|transcribed|failed)
    - `updatedAt` (Date)
    - `transcriptClean` (String, optional)
    - `audio` (Asset)
- Indexes (recommended for queries used by the app)
  - Queryable indexes on: `updatedAt` (for incremental fetch), `id` (for single‑record fetch)

## Run & Validate (on device)
1. Build & Run. Grant microphone permission.
2. Tap the mic to record a short entry, then tap again to stop.
3. The entry appears in the list. Open it and play back audio; scrubber should work.
4. In CloudKit Dashboard → Private DB → `Entry`, confirm a new record exists with an `audio` asset and fields populated.
5. CloudKit push: With the app installed, create or modify an `Entry` in Dashboard and confirm the app refreshes (silent push → list updates).

## Troubleshooting
- iCloud auth
  - Ensure device is signed into iCloud and the app has CloudKit container access.
- Subscription / Push not triggering refresh
  - Capabilities: Push + Background Remote notifications must be enabled.
  - Check device Settings → Notifications → allow for your app.
  - Confirm `aps-environment` is present in the .entitlements (Debug build shows `development`).
  - In Dashboard, verify a database subscription exists (the app creates one on launch).
- “Not authorized” or permission errors
  - Verify the container identifier matches the app’s entitlements.
  - Confirm the Development environment is selected in Dashboard.
- Missing audio in records
  - Ensure the `audio` field type is `Asset` and the app saved without error.

## Optional Validation
- Multi‑device: install on a second device; record on device A and confirm it appears on device B.
- Export: Create an export and share the folder; confirm it contains `.m4a` and `.txt` files.

