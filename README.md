# My Day (iCloud‑Only)

An iOS app that records short audio diary entries and stores them directly in iCloud using CloudKit — no custom server, database, or Docker stack.

## Features
- Record audio with a friendly, kid‑oriented UI and haptics
- Save entries to CloudKit with audio as `CKAsset`
- Entries list with colorful status icons and a handy summary
- Entry detail with playback, scrubber, and last‑position resume
- Live updates via CloudKit push notifications
- Local export: build a folder with `.m4a` and `.txt` files and share it

## Tech Stack
- SwiftUI + Concurrency (async/await)
- AVFoundation (`AVAudioRecorder`, `AVAudioPlayer`)
- CloudKit (`CKContainer`, `CKDatabase`, `CKRecord`, `CKAsset`, `CKDatabaseSubscription`)

## Project Structure
- CloudKit
  - `ios/MyDay/Services/CloudKit/CloudKitService.swift` — save/fetch entries, asset URL helper
  - `ios/MyDay/Services/CloudKit/CloudKitSubscriptions.swift` — ensures silent push subscription
- Audio
  - `ios/MyDay/Services/Audio/AudioRecorder.swift` — start/stop `.m4a` recording
  - `ios/MyDay/Services/Audio/AudioPlayer.swift` — playback with timer + seek
  - `ios/MyDay/Services/Audio/PlaybackPositionStore.swift` — save/restore last position
- Export
  - `ios/MyDay/Services/Export/LocalExportService.swift` — builds export folder
- App wiring
  - `ios/MyDay/AppModel.swift` — iCloud refresh, save recording flow
  - `ios/MyDay/AppDelegate.swift` — remote notif handling → refresh
  - `ios/MyDay/MyDayApp.swift` — app entry, tint, notifications
- UI Components
  - `ios/MyDay/RecordButton.swift` — colorful mic button
  - `ios/MyDay/EntryListView.swift`, `EntryDetailView.swift`, `ExportListView.swift`
  - `ios/MyDay/Components/PlayfulEmptyState.swift`, `LargeTitleView.swift`
  - `ios/MyDay/Theme/Theme.swift`, `ButtonStyles.swift`

## iOS Setup
1. Open the iOS project in Xcode.
2. Capabilities → iCloud → enable CloudKit and create/select a container (e.g., `iCloud.com.yourdomain.myday`).
3. Capabilities → Push Notifications and Background Modes → Remote notifications.
4. Info.plist keys:
   - `NSMicrophoneUsageDescription` = “This app records audio to save your diary entry.”
5. CloudKit Dashboard → Private Database → Record Type `Entry` with fields:
   - `id` (String), `createdAt` (Date), `duration` (Double), `sizeBytes` (Int/Int64),
   - `status` (String: uploaded|transcribed|failed), `updatedAt` (Date),
   - `transcriptClean` (String, optional), `audio` (Asset)
6. Build and run on a device signed into iCloud.

## Usage
- Tap the microphone to start/stop recording. The app saves the file to iCloud and refreshes the list.
- Tap an entry to open playback with a scrubber. Position is remembered.
- Exports tab → “Create Export” to generate a folder with audio and transcripts, then share.

## Known Limitations (MVP)
- Online‑first; CloudKit handles offline retries, but recording requires eventual connectivity to sync.
- No server‑side transcription in this build; transcript text appears only if set when saving.
- Export produces a folder, not a zip.
- Basic error handling; polish and localization not complete.

## Housekeeping
- Removed server/Docker code. If a leftover `myday_dev.db` exists at repo root, delete it.
- `PLAN.md` contains legacy notes (server & transcription). See this README for the iCloud‑only scope.

## License
Internal prototype/MVP. Do not distribute without permission.
