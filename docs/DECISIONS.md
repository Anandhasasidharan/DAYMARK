# LifeOS implementation decisions

- As of 2026-11-12 the user's active scope is Windows only. Mobile work and tooling
  are deferred. Personal use and no paid maintenance remain requirements. Cloud
  phases are excluded.
- Keep Flutter/Dart and offline SQLite; no hosted app or substitute web service.
- Source lives in `lifeos`; original handoff files remain unchanged.
- Use one Windows Flutter SDK and prepare one target at a time. Install no duplicate
  Linux SDK, Android toolchain/emulator, Node stack or server for the Windows build.
- SQLite, application-directory lookup and IANA time-zone packages form the core.
  Use the official Material UI package on current Flutter. Windows-specific storage
  avoids unused mobile/JNI dependencies; file selection and Windows toasts provide
  the required native features.
- No sample records, credentials, automatic telemetry or runtime network clients.
- SQLite schema 2 retains validated JSON records, plus general local entries and
  deletion markers. Migration from schema 1 adds tables while preserving records.
- Manual JSON transfer uses stable IDs and most-recent UTC edits. Tombstones protect
  deletions; equal timestamps favor deletion. Preferences stay local on import.
- Recurrence creates the next task transactionally with a deterministic series/date
  ID. Reopening a task does not erase its next occurrence.
- Career stage and goal target/unit histories are maintained by the repository.
  Actual goal progress is explicitly entered. Milestones are editable checklists.
- Habit status is a separate dated record. Explicit skips/rest days are excluded
  from streaks/adherence. Schedule edits currently affect historical calculations.
- Charts use Flutter widgets, numeric labels, date ranges and documented formulas.
  No chart dependency, composite score, guessed response rate or medical inference.
- Photo thumbnails are capped at 320 x 320 and included in JSON. Originals remain
  untouched. This saves disk and avoids an unbounded full-resolution photo archive.
- Windows toast reminders are opt-in and fire only while the app is running.
  There is no background service, scheduled task installation or startup agent.
- Build-Windows.cmd runs validation and a native release build on Windows. It does
  not install tooling or create extra release archives. With the newly granted execution access, native Windows commands and downloads
  work. The Windows release was built and launched on 2026-11-12.
- Keep runtime/build limitations explicit. Source checks are never Flutter test or
  Windows device validation claims.

- Installed one local Flutter 3.50.0 SDK (Dart 3.14.0), Build Tools 2022 17.14.45,
  Windows SDK 10.0.26100, CMake and ATL. No full Visual Studio IDE, Android SDK,
  emulator, server or second Linux Flutter SDK was installed.
- Project-local plugin junctions avoid changing Windows Developer Mode. Build scripts
  suppress development telemetry and optional SDK version checks. The SDK's fetched
  historical tags were pruned while preserving its stable release, reclaiming 453 MB.
- A desktop shortcut and Run-LifeOS.cmd launch the built app without invoking Flutter.
  Rebuilds stop early if this app is running, preserving unsaved work.
