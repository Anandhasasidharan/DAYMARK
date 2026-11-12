import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app.dart';
import 'package:lifeos/core/app_controller.dart';
import 'package:lifeos/data/repository.dart';
import 'package:lifeos/domain/models.dart';
import 'package:lifeos/domain/records.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);
  for (final width in [360.0, 1280.0]) {
    testWidgets('task create and completion on width $width', (tester) async {
      final repo = MemoryRepository();
      final app = AppController(repo);
      await app.initialize();
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        app.dispose();
      });
      await tester.pumpWidget(LifeOSApp(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Task title'),
        'Read SQL notes',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Read SQL notes'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect((await repo.load()).tasks.single.done, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

// UI tests use immediate in-memory operations; repository tests exercise SQLite.
class MemoryRepository implements TrackerRepository {
  final Map<String, TaskRecord> tasks = {};
  final Map<String, ActivityRecord> activities = {};
  final Map<String, LocalEntry> entries = {};
  Preferences preferences = const Preferences();
  @override
  Future<Snapshot> load() async => Snapshot(
    tasks.values.toList(),
    activities.values.toList(),
    preferences,
    entries.values.toList(),
  );
  @override
  Future<void> saveTask(TaskRecord task) async {
    tasks[task.id] = task;
  }

  @override
  Future<void> completeTask(TaskRecord task) async {
    await saveTask(task);
  }

  @override
  Future<void> saveEntry(LocalEntry entry) async {
    entries[entry.id] = entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    entries.remove(id);
  }

  @override
  Future<void> saveActivity(ActivityRecord activity) async {
    activities[activity.id] = activity;
  }

  @override
  Future<void> deleteTask(String id) async {
    tasks.remove(id);
  }

  @override
  Future<void> deleteActivity(String id) async {
    activities.remove(id);
  }

  @override
  Future<void> deleteAllRecords() async {
    tasks.clear();
    activities.clear();
    entries.clear();
  }

  @override
  Future<void> compactStorage() async {}
  @override
  Future<void> savePreferences(Preferences value) async {
    preferences = value;
  }

  @override
  Future<String> exportBackup() async => throw UnimplementedError();
  @override
  Future<void> importBackup(String source) async => throw UnimplementedError();
}
