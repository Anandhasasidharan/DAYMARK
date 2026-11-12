import 'dart:io';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_controller.dart';
import '../../domain/models.dart';
import '../../ui/common.dart';
import '../../core/local_files.dart';
import '../../domain/export.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;
  Future<void> backup(BuildContext context, bool restore) async {
    String contents;
    try {
      contents = restore ? '' : await app.repository.exportBackup();
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      return;
    }
    if (!context.mounted) return;
    final source = await showDialog<String>(
      context: context,
      builder: (_) => BackupDialog(restore: restore, contents: contents),
    );
    if (restore && source != null) {
      final ok = await app.run(() => app.repository.importBackup(source));
      if (ok && context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup merged. Existing newer records were kept.'),
          ),
        );
    }
  }

  Future<void> fileAction(BuildContext context, String action) async {
    try {
      if (action == 'open') {
        final source = await openBackupFile();
        if (source != null && context.mounted) {
          final json = jsonDecode(source) as Map<String, dynamic>;
          final accepted = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Merge this backup?'),
              content: Text(
                '${(json['tasks'] as List?)?.length ?? 0} tasks, ${(json['activities'] as List?)?.length ?? 0} activity logs, '
                '${(json['entries'] as List?)?.length ?? 0} other entries. Newer changes and deletion records will be applied. Save your current backup first.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Merge backup'),
                ),
              ],
            ),
          );
          if (accepted == true)
            await app.run(() => app.repository.importBackup(source));
        }
      } else {
        final contents = action == 'csv'
            ? recordsCsv(app.tasks, app.activities, app.entries)
            : await app.repository.exportBackup();
        final saved = await saveTextFile(
          contents,
          action == 'csv' ? 'lifeos-records.csv' : 'lifeos-backup.json',
        );
        if (saved && context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File saved to your chosen location.'),
            ),
          );
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('File action failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = app.snapshot.preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          'Your space. Your settings.',
          'Private, offline, and stored on this device.',
        ),
        const Section(
          title: 'Personal use only',
          child: Text(
            'LifeOS needs no account, server, hosting, or subscription. It does not send your records anywhere. '
            'Records stay on this Windows laptop. Backups are files you choose to save. '
            'Backups and the local database are not encrypted by LifeOS; protect them with your device lock and disk encryption.',
          ),
        ),
        Section(
          title: 'Appearance',
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: prefs.theme,
            decoration: const InputDecoration(
              labelText: 'Theme',
              border: OutlineInputBorder(),
            ),
            items: ['system', 'light', 'dark']
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: app.busy
                ? null
                : (theme) => app.run(
                    () => app.repository.savePreferences(
                      Preferences(
                        zone: prefs.zone,
                        theme: theme!,
                        desktopReminders: prefs.desktopReminders,
                        weekStart: prefs.weekStart,
                      ),
                    ),
                  ),
          ),
        ),
        Section(
          title: 'Start of week',
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: prefs.weekStart,
            items: List.generate(
              7,
              (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(
                  const [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday',
                  ][i],
                ),
              ),
            ),
            onChanged: app.busy
                ? null
                : (day) => app.run(
                    () => app.repository.savePreferences(
                      Preferences(
                        zone: prefs.zone,
                        theme: prefs.theme,
                        desktopReminders: prefs.desktopReminders,
                        weekStart: day!,
                      ),
                    ),
                  ),
          ),
        ),
        Section(
          title: 'Time zone',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prefs.zone),
              const SizedBox(height: 8),
              const Text(
                'Controls the current day. Dates already assigned to tasks and logs stay on their recorded day.',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: app.busy
                    ? null
                    : () async {
                        final zone = await showDialog<String>(
                          context: context,
                          builder: (_) => ZoneDialog(zone: prefs.zone),
                        );
                        if (zone != null)
                          await app.run(
                            () => app.repository.savePreferences(
                              Preferences(
                                zone: zone,
                                theme: prefs.theme,
                                desktopReminders: prefs.desktopReminders,
                                weekStart: prefs.weekStart,
                              ),
                            ),
                          );
                      },
                child: const Text('Change time zone'),
              ),
            ],
          ),
        ),
        Section(
          title: 'Backup & transfer',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save a JSON backup to a location you choose, or use clipboard transfer. '
                'JSON includes every record and photo thumbnail. CSV is for spreadsheets and excludes photo images. '
                'Imports merge newer edits and deletion records by ID. Keep device clocks correct. '
                'Theme and time zone stay on each device.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: app.busy ? null : () => backup(context, false),
                    icon: const Icon(Icons.copy),
                    label: const Text('Export backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: app.busy ? null : () => backup(context, true),
                    icon: const Icon(Icons.input),
                    label: const Text('Paste backup'),
                  ),
                  if (Platform.isWindows)
                    FilledButton.tonal(
                      onPressed: app.busy
                          ? null
                          : () => fileAction(context, 'save'),
                      child: const Text('Save JSON file'),
                    ),
                  OutlinedButton(
                    onPressed: app.busy
                        ? null
                        : () => fileAction(context, 'open'),
                    child: const Text('Open JSON file'),
                  ),
                  if (Platform.isWindows)
                    OutlinedButton(
                      onPressed: app.busy
                          ? null
                          : () => fileAction(context, 'csv'),
                      child: const Text('Save CSV file'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Section(
          title: 'Desktop reminders',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow Windows desktop reminders'),
                subtitle: const Text(
                  'LifeOS must remain open. Windows settings or Do not disturb can suppress notifications. Reminder text may appear on your screen.',
                ),
                value: prefs.desktopReminders,
                onChanged: !Platform.isWindows || app.busy
                    ? null
                    : (enabled) => app.run(
                        () => app.repository.savePreferences(
                          Preferences(
                            zone: prefs.zone,
                            theme: prefs.theme,
                            desktopReminders: enabled,
                            weekStart: prefs.weekStart,
                          ),
                        ),
                      ),
              ),
              OutlinedButton(
                onPressed:
                    !Platform.isWindows || app.busy || !prefs.desktopReminders
                    ? null
                    : () => app.run(
                        () => app.desktopReminders.show(
                          'LifeOS',
                          'Your local reminder test.',
                        ),
                      ),
                child: const Text('Test desktop notification'),
              ),
            ],
          ),
        ),
        const Section(
          title: 'Connections',
          child: Text(
            'Cloud sync: not connected\nGoogle Calendar: not connected\nAuthentication: not connected\nDesktop reminders: local, opt-in; app must stay open\n\nNo connection is needed to use this app.',
          ),
        ),
        Section(
          title: 'Local data',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compact storage reclaims unused database pages after deletions. It temporarily needs free disk space. Your records stay in place.',
              ),
              OutlinedButton(
                onPressed: app.busy
                    ? null
                    : () => app.run(() => app.repository.compactStorage()),
                child: const Text('Compact database'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: app.busy
                    ? null
                    : () async {
                        final accepted = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text(
                              'Delete all records on this device?',
                            ),
                            content: const Text(
                              'Export a backup first. This removes tasks, logs, goals, habits, reviews and photo thumbnails. Imported deletion records can also remove them on your other device. Exported files are kept.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Keep records'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete all records'),
                              ),
                            ],
                          ),
                        );
                        if (accepted == true)
                          await app.run(
                            () => app.repository.deleteAllRecords(),
                          );
                      },
                child: const Text('Delete all records'),
              ),
            ],
          ),
        ),
        const Text('LifeOS 0.2.0 · Local edition'),
      ],
    );
  }
}

class BackupDialog extends StatefulWidget {
  const BackupDialog({
    super.key,
    required this.restore,
    required this.contents,
  });
  final bool restore;
  final String contents;
  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  late final TextEditingController controller;
  String? message;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.contents);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.restore ? 'Import a LifeOS backup' : 'Export your backup',
    ),
    content: SizedBox(
      width: 580,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.restore
                  ? 'Paste backup JSON. This merges records and deletions into this device. Save a backup before importing.'
                  : 'Copy all JSON and save it as lifeos-backup.json in a safe location. It contains your personal records.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              readOnly: !widget.restore,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Backup JSON',
              ),
            ),
            if (message != null) Text(message!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      if (widget.restore)
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Merge backup'),
        )
      else
        FilledButton(
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: controller.text));
              if (mounted)
                setState(
                  () => message = 'Copied. Save the text before closing.',
                );
            } catch (e) {
              if (mounted)
                setState(
                  () => message =
                      'Copy failed. Select the text and copy manually.',
                );
            }
          },
          child: const Text('Copy all'),
        ),
    ],
  );
}

class ZoneDialog extends StatefulWidget {
  const ZoneDialog({super.key, required this.zone});
  final String zone;
  @override
  State<ZoneDialog> createState() => _ZoneDialogState();
}

class _ZoneDialogState extends State<ZoneDialog> {
  late final TextEditingController controller;
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.zone);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose a time zone'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'IANA zone',
          helperText: 'Examples: Asia/Kolkata, Europe/London, Etc/UTC',
        ),
        validator: (value) {
          try {
            tz.getLocation(value?.trim() ?? '');
            return null;
          } catch (_) {
            return 'Enter a valid IANA time zone';
          }
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate())
            Navigator.pop(context, controller.text.trim());
        },
        child: const Text('Save'),
      ),
    ],
  );
}
