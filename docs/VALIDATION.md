# Windows validation — 2026-11-12

## Result

The native Windows release **built successfully and launched**. The process remained
responsive and rendered the main interface (Learning screen captured locally at
`build/windows-launch.png`). Local database initialization completed; the app did
not remain in the startup error/retry screen. No demo records were inserted into
the user's database during verification.

Executable: `build/windows/x64/runner/Release/lifeos.exe`.
Release folder: approximately **31 MB**, including the required DLLs and `data`.
A **LifeOS** shortcut was created on the Windows desktop. `Run-LifeOS.cmd` is the
project-local launcher and does not run Flutter or download anything.

## Actual checks

| Check | Result |
| --- | --- |
| Windows Flutter doctor | Passed, no issues found |
| Dart formatting | 34 files, final run 0 changes |
| Flutter analysis | Passed, no issues found |
| Automated tests | **26 passed**, 0 failed in the final full run |
| Windows release compilation | Passed after installing required ATL headers |
| Native executable launch | Passed; responsive main window, local storage initialized |
| Visual startup inspection | Passed; the real Windows interface rendered |

Commands executed natively through Windows PowerShell using the local SDK:

```powershell
flutter --no-version-check doctor -v
dart format lib test
flutter --no-version-check --suppress-analytics analyze
flutter --no-version-check --suppress-analytics test
flutter --no-version-check --suppress-analytics build windows --release --no-pub
```

The build script runs the equivalent validation pipeline. It stops early if this
app is running, so it does not overwrite a running executable or discard an
unsaved timer. Close LifeOS before choosing Build-Windows.cmd again.

## Toolchain and resolved build issues

- Windows 11, version 10.0.26300.9974, x64.
- Flutter **3.50.0**, stable; Dart **3.14.0**.
- Visual Studio **Build Tools 2022 17.14.45**, MSVC/CMake and Windows SDK **10.0.26100**.
- **ATL** headers are also required by the Windows toast plugin and were installed.
- One SDK in `.toolchain/flutter`; Build Tools in `.toolchain/buildtools`.
- No full Visual Studio IDE, Android SDK, emulator, Linux Flutter SDK or server.
- Official `material_ui` replaces the SDK's deprecated Material import.
- `path_provider_windows` removes unused mobile/JNI dependencies from this build.
- Project-local plugin junctions resolve Windows link privileges without changing
  Developer Mode. Build scripts prepare them automatically.
- SDK/toolchain paths are excluded from the app's analysis and Git tracking.
- Unneeded SDK Git history was reduced from **489.1 MB to 35.6 MB**, preserving the
  installed stable version and current release tag. Completed installer downloads
  and temporary checks were removed. Flutter/Dart development telemetry is disabled.

The earlier sandbox DNS/Windows-interoperability restrictions were resolved using
the newly granted execution access; they are no longer the build status.

## Test coverage

- Day aggregation, denominators, empty dates/year boundaries, IANA time zones.
- Invalid dates/durations/counts and oversized imported text.
- Habit eligible dates, skipped days, current-day grace, adherence and streaks.
- CSV quote/newline handling and formula escaping.
- Real SQLite CRUD, settings, file close/reopen and schema-1 migration.
- Backup restore/idempotency, last-edit conflicts and malformed imports.
- Deletion protection, delete-all and compaction preserving valid records.
- Recurring task deduplication, career history and goal target history.
- Task creation/completion at narrow and wide window sizes.
- Windows goal validation/entry and habit check-in UI flows.

The first UI run exposed navigation/dropdown overflow. The layouts were fixed;
the affected four UI tests passed, followed by all 26 tests in the final full run.

## Practical limits and remaining manual checks

Native file dialogs, photo picking and opt-in toast delivery are compiled into the
release but have not all been manually exercised end to end. Use Settings to test
a Windows notification after opting in. Windows settings can suppress alerts.
Reminder delivery requires LifeOS to stay open; no background service is installed.
Closing the app discards an unsaved study timer. Habit schedule edits affect
historical schedule-based calculations. These limitations remain documented in
README.md and the UI.

For personal acceptance, try each module with your own entries, close/reopen to
check persistence, save a JSON backup, and test importing a copy. Keep the full
Release folder together. `flutter clean` removes that build output, so preserve a
working bundle first if you deliberately clean it. Mobile remains deferred.
