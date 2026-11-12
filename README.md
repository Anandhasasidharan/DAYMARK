# Daymark

**Make progress visible, one day at a time.**

A private Windows app for planning your day and tracking learning, career,
exercise, and personal care. Daymark brings tasks, habits, goals, activity logs,
and weekly reviews into one place, with progress calculated from your records.

**Windows · Flutter · SQLite · Offline · Personal use**

Daymark is the project name. The current Windows app, desktop shortcut, executable,
and source folder use the original name **LifeOS**; the launch instructions below
use those existing names.

## Built for your own laptop

- Use it without an account, subscription, hosting, or backend.
- Keep records in a local SQLite database.
- Plan future tasks separately from activities you actually completed.
- Export your records and keep your own backups.
- Work offline after installation.

The current release targets **Windows only**. Mobile development is deferred.

## Run the app

Open the **LifeOS** shortcut on your Windows desktop, or double-click:

```text
Run-LifeOS.cmd
```

This launches the existing app without rebuilding or downloading anything.
Flutter and the compiler are only needed to develop or rebuild it.

The executable is located at:

```text
build\windows\x64\runner\Release\lifeos.exe
```

Keep the **entire Release folder** together, including its DLLs and `data` folder.
The release folder is approximately **31 MB**. Personal records are stored
separately in the Windows application-support directory.

## Features

| Area | What you can do |
| --- | --- |
| Home | View today's plan, actual completions, study time, habit check-ins, streaks, upcoming tasks, and career follow-ups. |
| Daily planner | Add, edit, search, reschedule, prioritize, complete, reopen, or delete tasks. Set times, link goals, and repeat tasks daily or weekly. |
| Learning | Log study sessions, use a pause/resume timer, record practice attempts and scores, manage revisions, and track projects. |
| Career | Track companies, roles, links, contacts, application stages, stage history, notes, and follow-up dates. |
| Exercise | Record workouts and rest days, minutes, sets, reps, weight, distance, and body measurements. |
| Personal care | Log routines, products, treatments, observations, and private progress photo thumbnails. |
| Goals and projects | Set measurable targets, enter actual progress, keep target history, link tasks/sessions, and check off milestones. |
| Habits | Choose weekdays and start/end dates, pause routines, and record dated done/skipped check-ins. |
| Weekly reviews | Review saved metrics and write down wins, blockers, and next week's focus. |
| Analytics | Explore study time, tasks, workout frequency, care adherence, practice accuracy, and career stages over 7 days, 30 days, or a custom range. |
| Settings | Choose theme, time zone and start-of-week; manage reminders, backups, exports, storage, and record deletion. |

**Keyboard shortcut:** `Ctrl+N` opens a new task.

## Progress without guesswork

- **Study time:** the sum of logged session durations.
- **Task completion:** currently completed tasks grouped by their planned date.
- **Practice accuracy:** total correct answers divided by total attempted answers.
- **Workout frequency:** exercise log entries, excluding the rest workout type.
  Multiple exercise entries count separately.
- **Habit adherence:** completed scheduled instances divided by eligible instances,
  excluding explicit skips. Rest/skipped days are also excluded from streaks.
- **Goal progress:** a measurement you enter explicitly; task completion does not
  guess how much of a goal you achieved.

Missing activity is shown as **not logged**. Dates without planned tasks are shown
as **no plan**. Charts disclose their units, date ranges, and calculations.

## Back up your records

1. Open **Settings → Save JSON file** and choose a local location.
2. Keep a separate copy somewhere safe before importing or deleting records.
3. To restore or merge a backup, choose **Open JSON file**, review the record counts,
   and select **Merge backup**.

Clipboard JSON export/import is also available. Use **Save CSV file** for
spreadsheets; CSV is an export format, not a restore format.

JSON includes all records and photo thumbnails. Imports validate records before
applying them in a transaction. For matching IDs, newer UTC edits win; deletion
markers prevent older backups from restoring deleted entries. Equal timestamps
favor deletion. Keep your device clock accurate. Device preferences stay local.

Supported imports include version-1 and version-2 LifeOS backups, up to **25 MB**.
CSV excludes image data and escapes formula-like text for spreadsheet safety.

## Privacy

The app makes no runtime network requests and includes no telemetry, cloud sync,
authentication, or public storage service. No API keys are required.

The database and backup files are **not encrypted by the app**. Protect them with
your Windows account, device lock, and disk encryption. Choose a local save location
if you want backups confined to your laptop; clipboard and file-sync software can
have their own synchronization settings.

Photo imports store a thumbnail up to **320 × 320** rather than copying a large
original into the app. The original file stays untouched. Photos are not analyzed
for recognition or medical diagnosis.

## Current limitations

- Desktop reminders are opt-in and require the app to remain open. Windows settings
  can suppress them; background delivery after closing the app is not implemented.
- Closing the app discards an unsaved study timer. The timer saves whole completed
  minutes to the date on which you save the session.
- Editing a task changes its current-plan chart. Editing or pausing a habit changes
  its schedule-based historical calculations.
- Photo storage preserves thumbnails, not full-resolution originals.
- Custom analytics ranges are limited to 366 days.
- Automatic device sync, cloud integrations, and mobile builds are outside the
  current Windows milestone.

## Build on Windows

The app was built and launched on **2026-11-12** using:

| Tool | Validated version |
| --- | --- |
| Flutter | 3.50.0 stable |
| Dart | 3.14.0, bundled with Flutter |
| Microsoft Visual Studio Build Tools 2022 | 17.14.45 |
| Windows SDK | 10.0.26100 |

Building requires the C++ compiler, CMake, Windows SDK, and **C++ ATL** headers.
The package constraints require Flutter 3.47+ and Dart 3.13+.

This laptop's SDK is in `.toolchain/flutter`, and its compiler tools are in
`.toolchain/buildtools`. The build scripts detect the local SDK automatically.
Reuse these installations; a separate Dart SDK, Linux Flutter SDK, Android SDK,
emulator, Node installation, or server is unnecessary for this build.

**Close LifeOS before rebuilding.** Then run from Windows PowerShell:

```powershell
Set-Location D:\LEARINING\tracker\lifeos
.\Build-Windows.cmd
```

The command resolves packages, prepares Windows plugin links, formats code, runs
analysis and tests, builds the release, and launches it after successful checks.
It preserves a running app instead of overwriting its executable. Project-local
junctions avoid changing Windows Developer Mode.

To build without launching:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build-windows.ps1
```

Initial tool/package downloads need internet access. Running the built app does not.
The scripts do not automatically install toolchains or publish the app.

## Project structure

```text
lifeos/
├── lib/
│   ├── core/          # State, clock, file operations, desktop reminders
│   ├── data/          # SQLite, migrations, backup merging, deletion markers
│   ├── domain/        # Validated records, metrics, CSV export
│   ├── features/      # Planner, modules, goals, habits, reviews, settings
│   └── ui/            # Shared forms and lists
├── test/              # Calculation, repository, migration, and widget tests
├── windows/           # Native Windows runner
├── tool/              # Windows setup and build scripts
├── docs/              # Decisions and validation details
├── Build-Windows.cmd  # Check, rebuild, and launch
└── Run-LifeOS.cmd     # Launch the existing release
```

Keep `pubspec.lock` for reproducible package resolution. Generated builds, local
SDK/compiler files, databases, and backups are excluded from Git.

## Validation and storage

**Static analysis is clean, all 26 automated tests passed, and the native Windows
executable was launched and visually checked.** Tests cover calculations, input
validation, persistence after reopening, schema migration, recurring tasks,
histories, backup conflicts, deletion protection, and representative UI flows.

See [validation results](docs/VALIDATION.md) for the execution record and remaining
manual checks, and [implementation decisions](docs/DECISIONS.md) for the design.

Keep one working release bundle. Do not routinely clear SDK/package caches, which
would force downloads again. `flutter clean` deletes generated build files,
**including the executable**; preserve a working Release folder first.

Deleting records does not automatically remove separately exported files. Use
**Compact database** to reclaim unused pages after deletions; compaction temporarily
needs free disk space. Records are never automatically purged.
