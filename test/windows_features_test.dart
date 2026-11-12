import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app.dart';
import 'package:lifeos/core/app_controller.dart';
import 'package:lifeos/core/clock.dart';
import 'package:lifeos/domain/models.dart';
import 'package:lifeos/domain/records.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'widget_test.dart' show MemoryRepository;

void main() {
  setUpAll(tz_data.initializeTimeZones);
  testWidgets(
    'Windows goal form rejects zero target and persists a valid goal',
    (tester) async {
      final repo = MemoryRepository();
      final app = AppController(repo);
      await app.initialize();
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        app.dispose();
      });
      await tester.pumpWidget(LifeOSApp(controller: app));
      await tester.pumpAndSettle();
      final destination = find.widgetWithText(
        NavigationDrawerDestination,
        'Goals & projects',
      );
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Learn SQL',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Unit (hours, questions, workouts…) *',
        ),
        'hours',
      );
      final target = find.widgetWithText(TextFormField, 'Target *');
      await tester.ensureVisible(target);
      await tester.enterText(target, '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.entries, isEmpty);
      expect(find.textContaining('Target must be between'), findsOneWidget);
      await tester.ensureVisible(target);
      await tester.enterText(target, '20');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.entries.values.single.title, 'Learn SQL');
      expect(repo.entries.values.single.number('target'), 20);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Windows habit check-in records actual completion', (
    tester,
  ) async {
    final repo = MemoryRepository();
    final today = dateKey(AppClock('Asia/Kolkata').now);
    final stamp = DateTime.now().toUtc().toIso8601String();
    await repo.saveEntry(
      LocalEntry(
        id: 'habit',
        kind: EntryKind.habit,
        title: 'Daily movement',
        category: Category.fitness,
        day: today,
        createdAt: stamp,
        updatedAt: stamp,
        values: {'weekdays': '1,2,3,4,5,6,7', 'status': 'active', 'end': ''},
      ),
    );
    final app = AppController(repo);
    await app.initialize();
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      app.dispose();
    });
    await tester.pumpWidget(LifeOSApp(controller: app));
    await tester.pumpAndSettle();
    final destination = find.widgetWithText(
      NavigationDrawerDestination,
      'Habits',
    );
    await tester.ensureVisible(destination);
    await tester.tap(destination);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final checkin = repo.entries.values.singleWhere(
      (e) => e.kind == EntryKind.occurrence,
    );
    expect(checkin.text('status'), 'done');
    expect(checkin.day, today);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
