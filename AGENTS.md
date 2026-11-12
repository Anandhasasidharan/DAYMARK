# LifeOS local edition

Read README.md and docs/DECISIONS.md before making changes. The user's latest
instruction is Windows only for now, personal use on their laptop, with no paid maintenance.
Leave mobile implementation and tooling aside until explicitly requested again.
Keep all functionality offline and avoid backend services, cloud accounts,
telemetry, subscriptions and deployment. Transfers are explicit local backups.

Use Flutter/Dart and SQLite. Preserve validated models and local persistence.
Run dart format, flutter analyze and flutter test when an SDK is available; never
claim unavailable checks passed. Document device/build limitations honestly.
Do not store signing keys, backups, databases or personal records in Git.

Keep disk use low. Reuse installed tools; do not install duplicate SDKs, emulators,
full platform toolchains or extra packages speculatively. Prepare one target at a
time with tool/bootstrap.ps1. Preserve personal data and installed app storage.

Windows build status (2026-11-12): release built and launched; analysis clean and
26 tests passed. Use the local SDK in .toolchain/flutter; it is excluded from
analysis and Git. Run-LifeOS.cmd launches without rebuilding. Preserve runtime
app data. Close LifeOS before compiling updates; never force-kill an unsaved timer.
The Windows notification plugin needs MSVC ATL as well as compiler/CMake/SDK.
