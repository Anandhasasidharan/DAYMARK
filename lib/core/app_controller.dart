import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/records.dart';
import 'clock.dart';
import 'desktop_reminders.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final TrackerRepository repository;
  Snapshot snapshot = const Snapshot([], [], Preferences());
  String? error;
  final studyStopwatch = Stopwatch();
  final desktopReminders = DesktopReminders();
  bool _checkingReminders = false;
  bool busy = false;
  AppClock get clock => AppClock(snapshot.preferences.zone);
  List<LocalEntry> get entries => snapshot.entries;
  List<TaskRecord> get tasks => snapshot.tasks;
  List<ActivityRecord> get activities => snapshot.activities;
  Future<void> initialize() async {
    snapshot = await repository.load();
  }

  void dismissError() {
    error = null;
    notifyListeners();
  }

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      snapshot = await repository.load();
      return true;
    } catch (e) {
      error =
          'Could not finish the action. Your saved records remain on this device. Details: $e';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> toggle(TaskRecord task) async {
    final json = task.toJson();
    final now = DateTime.now().toUtc().toIso8601String();
    json['completedAt'] = task.done ? null : now;
    json['updatedAt'] = now;
    await run(() => repository.completeTask(TaskRecord.fromJson(json)));
  }

  Future<bool> setHabitStatus(LocalEntry habit, String day, String? status) =>
      run(() async {
        if (day.compareTo(clock.today) > 0 || !habitEligible(habit, day))
          throw const FormatException(
            'This habit is not scheduled on that date.',
          );
        final id = '${habit.id}:$day';
        if (status == null) {
          await repository.deleteEntry(id);
          return;
        }
        if (!['done', 'skipped'].contains(status))
          throw const FormatException('Invalid check-in.');
        final matches = entries.where((e) => e.id == id);
        final now = DateTime.now().toUtc().toIso8601String();
        await repository.saveEntry(
          LocalEntry(
            id: id,
            kind: EntryKind.occurrence,
            title: habit.title,
            category: habit.category,
            day: day,
            createdAt: matches.isEmpty ? now : matches.first.createdAt,
            updatedAt: now,
            values: {'habitId': habit.id, 'status': status},
          ),
        );
      });
  Future<void> checkReminders() async {
    if (busy ||
        _checkingReminders ||
        error != null ||
        !snapshot.preferences.desktopReminders)
      return;
    _checkingReminders = true;
    try {
      final now = clock.now;
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final due = entries
          .where(
            (e) =>
                e.kind == EntryKind.reminder &&
                e.text('status') == 'enabled' &&
                (e.day.compareTo(clock.today) < 0 ||
                    (e.day == clock.today &&
                        e.text('time').compareTo(time) <= 0)),
          )
          .take(5)
          .toList();
      for (final entry in due) {
        if (busy) break;
        final json = entry.toJson();
        json['values'] = {...entry.values, 'status': 'delivered'};
        json['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        final saved = await run(() async {
          await desktopReminders.show('LifeOS reminder', entry.title);
          await repository.saveEntry(LocalEntry.fromJson(json));
        });
        if (!saved) break;
      }
    } catch (e) {
      error =
          'Windows reminder could not be delivered: $e. Your reminder remains saved.';
      notifyListeners();
    } finally {
      _checkingReminders = false;
    }
  }

  @override
  void dispose() {
    studyStopwatch.stop();
    desktopReminders.dispose();
    super.dispose();
  }
}
