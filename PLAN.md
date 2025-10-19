# My Day — Product & Technical Plan

## 0. Product Snapshot

**Platform:** iPhone-first SwiftUI app with optional web/API components.

**Authentication:** Sign in with Apple, Google Sign-In, or email/password handled by backend token exchange.

**Home Experience:**
- Prominent center record button with live waveform visualization (≥30 FPS).
- Tap toggles pause/resume; long-press (~3 seconds) stops recording with radial progress feedback.
- Secondary "Type instead" action opens text entry for manual diary input.

**Recording Output:**
- Audio saved as `.m4a` with filenames `YYYY-MM-DD_HH-mm-ss_<uuid8>.m4a` (sortable and unique).
- Offline capture supported; uploads queue until connectivity is restored.

**Transcription Pipeline:**
1. Upload audio to server.
2. Automatic speech recognition (ASR) via Whisper.
3. AI cleanup removes filler words, adds punctuation, and formats paragraphs.
4. Client syncs results automatically on launch or via manual pull-to-refresh.

**Library:**
- Accessed from top-left.
- Entries sorted by date; tap to view transcript and play audio.
- Displays status chips such as “Transcribing…”.

**Profile:**
- Shows total recordings and cumulative duration.
- Date-range export emails a `.zip` containing audio and cleaned transcripts.

**Onboarding Hint:** One-time tooltip: “Long-press ~3s to stop.”

## 1. Architecture & Stack

### Client (iOS — My Day)
- Swift + SwiftUI leveraging Swift Concurrency.
- Audio capture via AVFoundation/AVAudioEngine.
- Waveform rendering with SwiftUI `Canvas` + Accelerate for RMS/FFT sampling.
- State management through `ObservableObject` and `async/await` flows.
- Metadata in Core Data; audio files stored in the app’s Documents directory.
- Background uploads using `URLSession` (background configuration) and `BGTaskScheduler` for sync.
- Authentication handled with AuthenticationServices (Apple), GoogleSignIn, and custom email login routed to backend.

### Server (My Day API)
- FastAPI (Python) or NestJS (Node) for REST endpoints.
- Whisper (faster-whisper) workers for transcription.
- LLM pass for filler removal, punctuation, and paragraph formatting.
- Storage via S3-compatible object store for audio, PostgreSQL for relational data, Redis for queues.
- JWT-based auth with Apple/Google token verification.
- Export pipeline builds zip bundles and sends links through SES or SendGrid.

## 2. Data Model

| Entity | Fields |
| --- | --- |
| **User** | `id`, `email`, `apple_sub?`, `google_sub?`, `created_at` |
| **Entry** | `id`, `user_id`, `created_at`, `duration_s`, `status {uploaded|transcribed|failed}`, `audio_url`, `size_bytes`, `language?`, `transcript_raw?`, `transcript_clean?` |
| **ExportRequest** | `id`, `user_id`, `from`, `to`, `status`, `result_url?`, `created_at` |

**Filename convention:** `YYYY-MM-DD_HH-mm-ss_<uuid8>.m4a` (stable, sortable, and unique).

## 3. UX Flow & Acceptance Criteria

### Record
- Start, pause, and resume recording seamlessly.
- Long-press 3 seconds to stop with visible radial progress.
- Waveform rendering stays smooth at or above 30 FPS.
- Offline operation supported; uploads retry automatically when online.

### Library
- Accessible from top-left navigation.
- Group entries by day/month with clear status indicators (e.g., “Transcribing…”).
- Manual pull-to-refresh triggers sync.

### Profile
- Display totals (count and duration).
- Export picker selects date range and emails `.zip` containing audio plus cleaned transcripts named `YYYY-MM-DD_HH-mm-ss.txt`.

### Accessibility
- VoiceOver announcements reflect state changes (recording, paused, stopped).
- Ensure large hit targets and meaningful accessibility hints.

## 4. Milestones (Modules Named `MyDay.*`)

1. **Scaffold:** SwiftUI app shell with icons, colors, typography tokens, bundle ID `com.yourdomain.myday`.
2. **Audio & Waveform:** `MyDayAudioService` for record/pause/resume/stop, `.m4a` output, live RMS/FFT feeding `WaveformView`.
3. **Local Library:** Core Data `Entry` entity, file management, list/detail views with playback.
4. **Auth:** Apple, Google, and email sign-in; `MyDayAuthService` exchanges tokens with backend and stores credentials in Keychain.
5. **Networking & Background Upload:** Background `URLSession`, retry/backoff logic, offline queue handling.
6. **Server MVP:** Auth endpoints, signed upload URLs, entry create/list, worker pipeline (ASR → cleanup), status polling.
7. **Sync:** Launch/manual sync merging statuses and transcripts with conflict resolution.
8. **Profile & Export:** Stats screen, date-range export emailing signed link.
9. **Polish:** Haptics, first-run hints, empty/error states, localization hooks.
10. **Security & QA:** Token rotation, rate limiting, unit/UI/integration tests.
11. **App Store:** Privacy labels, delete-account workflows, TestFlight, review notes.

## 5. iOS Implementation Notes

- Configure audio session: `.playAndRecord`, mode `.measurement`, options `.defaultToSpeaker`, `.allowBluetooth`.
- Use `AVAudioEngine` + `AVAudioFile`; record to temp file then atomically move on stop.
- Maintain ring buffer of RMS/short FFT samples; render via `Canvas` synced to display link.
- `LongPressGesture(minimumDuration: 3)` provides stop interaction with circular progress around record button.
- Background uploads use `URLSessionConfiguration.background(identifier: "com.yourdomain.myday.uploads")`; persist task IDs.
- Persist hint state with `@AppStorage("hasShownStopHint")`.
- Provide VoiceOver labels/hints; announce state transitions via `UIAccessibility.post`.

## 6. Server Implementation Notes

### Endpoints
- `POST /v1/auth/apple | google | email`
- `POST /v1/entries` → returns signed `PUT` URL + `entry_id`
- `GET /v1/entries?since=...` (paginated)
- `GET /v1/entries/{id}`
- `POST /v1/exports (from, to, email)`
- `GET /v1/exports/{id}`

### Worker Pipeline
1. Fetch audio blob.
2. Run Whisper transcription; store `transcript_raw`.
3. Invoke LLM cleanup with prompt: “Clean this diary transcript for readability. Remove filler words (uh/um/ah/like), add punctuation and casing, preserve meaning and tone. Don’t invent content.”
4. Save `transcript_clean`; mark entry as transcribed.

### Security Considerations
- Verify Apple identity token fields (`iss`, `aud`, `kid`); verify Google tokens via published certs.
- Issue short-lived JWTs with rotating refresh tokens.
- Signed URLs must be time-bound; enforce per-user/IP rate limits.

## 7. Testing Strategy

- **Unit:** Audio service, filename rules, persistence layer, API client.
- **UI:** Recording gesture states, hint display logic, offline upload queue behavior.
- **Integration:** End-to-end upload → transcription → sync flow.
- **Load:** Batch transcription throughput and export zip generation.
- **Edge Cases:** Phone call interruptions, low disk space, microphone denial, background termination.

## 8. “Use Codex Fully” Prompts

Ready-to-paste prompts for AI-assisted scaffolding (replace `yourdomain` accordingly):

A. **SwiftUI Scaffold — My Day**
> Create a SwiftUI iOS app named “My Day” (bundle id `com.yourdomain.myday`). Folders: `App`, `Features/{Home,Library,Profile}`, `Services/{Audio,Storage,API,Auth,Sync}`, `Models`, `Utilities`, `Tests`. Provide a `HomeView` with a centered record button and “Type instead” link. Include Core Data stack and an `AppTheme` for colors/typography.

B. **Audio + Waveform**
> Implement `MyDayAudioService` using `AVAudioEngine` to start/pause/resume/stop recording to AAC `.m4a` at 44.1 kHz. Expose `@Published` or async streams for `isRecording`, `isPaused`, `rmsLevel`, and `duration`. Add `RecordButtonView` (tap toggles pause/resume; long-press 3 s to stop with circular progress). Add `WaveformView` drawing 48–64 bars from a ring buffer at 60 fps via SwiftUI `Canvas`.

C. **Persistence & Filenames**
> Add Core Data entity `Entry { id: UUID, createdAt: Date, localAudioPath: String, duration: Double, status: String, sizeBytes: Int64 }`. Implement `EntryStore` with CRUD and migration. Filenames follow `YYYY-MM-DD_HH-mm-ss_<uuid8>.m4a`. Include unit tests.

D. **Background Upload**
> Implement `UploadService` using a background `URLSession`. `enqueueUpload(entry:)` returns a task ID; persist mapping; handle delegate callbacks to update status and retry with exponential backoff. Rehydrate pending tasks on app launch. Provide mocks/tests.

E. **Auth**
> Add Sign in with Apple (`AuthenticationServices`) and Google Sign-In. Implement `MyDayAuthService` to exchange identity tokens with backend for JWT/refresh; store in Keychain; auto-refresh. Include SwiftUI sign-in views and tests.

F. **Library & Detail**
> Build `LibraryView` grouped by date with pull-to-refresh, showing title (date/time), status pill, and duration. `EntryDetailView` plays audio and shows `transcript_clean` when available; show “Transcribing…” state otherwise. Add empty/error states.

G. **Sync**
> Implement `SyncService` that on app start and manual refresh pulls changed entries and merges by ID. Resolve conflicts preferring latest server status/`transcript_clean`. Include tests.

H. **FastAPI Server Scaffold**
> Generate a FastAPI project “myday-api” with routers: `auth`, `entries`, `exports`; Postgres via SQLModel; S3 (boto3) signed URLs; Celery+Redis workers; Docker Compose (api, worker, redis, db, minio). Include Apple/Google token verification endpoints.

I. **Transcription Worker**
> Implement Celery tasks: download audio, run faster-whisper, save `transcript_raw`, call LLM for cleanup with the given prompt, save `transcript_clean`, update entry status. Add retries and idempotency.

J. **Export**
> Implement `/v1/exports` to gather entries by date range, create a `.zip` with audio + cleaned `.txt` files named by timestamp, upload to storage, and email a signed link via SendGrid. Handle large ranges with pagination/chunking.

K. **First-run Hint & Haptics**
> Add a one-time coach mark near the record button: “Tip: Long-press ~3s to stop.” Provide haptics for start, pause/resume, and stop events. Include VoiceOver labels.

## 9. Performance, Privacy & Compliance

- Suspend audio engine when backgrounded; optionally restrict background uploads to Wi-Fi to conserve battery.
- Write to temporary file and commit atomically on stop; guard against clipping/overruns.
- Capture locale to select ASR language automatically.
- Provide `NSMicrophoneUsageDescription`: “My Day records audio to create your diary.”
- Profile screen must include delete account/data options and reference privacy policy; do not train models on user data without explicit consent.

## 10. Nice-to-have Roadmap

- Daily reminders to prompt recordings.
- Tags or moods (auto-suggested with manual edits).
- Optional on-device Apple Speech transcription for short notes.
- iCloud Drive export support.
