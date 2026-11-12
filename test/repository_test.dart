import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/data/repository.dart';
import 'package:lifeos/domain/models.dart';
import 'package:lifeos/domain/records.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'analytics_test.dart' show task, study;

void main() {
  late Directory directory;
  late LifeRepository repo;
  late String path;
  setUpAll(() {
    sqfliteFfiInit();
    tz_data.initializeTimeZones();
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lifeos_test_');
    path = '${directory.path}/lifeos.db';
    repo = await LifeRepository.open(path);
  });
  tearDown(() async {
    await repo.close();
    await directory.delete(recursive: true);
  });

  test(
    'create, edit, complete, reopen and delete survive a real database restart',
    () async {
      await repo.saveTask(task('a', '2026-11-02'));
      final edited = task('a', '2026-11-03', done: true).toJson()
        ..['title'] = 'Revised plan';
      await repo.saveTask(TaskRecord.fromJson(edited));
      await repo.saveActivity(study('study', '2026-11-02', 45));
      await repo.savePreferences(
        const Preferences(zone: 'Etc/UTC', theme: 'dark'),
      );
      await repo.close();
      repo = await LifeRepository.open(path);
      var saved = await repo.load();
      expect(saved.tasks.single.title, 'Revised plan');
      expect(saved.tasks.single.day, '2026-11-03');
      expect(saved.tasks.single.done, isTrue);
      expect(saved.activities.single.minutes, 45);
      expect(saved.preferences.theme, 'dark');
      await repo.deleteTask('a');
      await repo.deleteActivity('study');
      saved = await repo.load();
      expect(saved.tasks, isEmpty);
      expect(saved.activities, isEmpty);
    },
  );
  test('each module preserves its structured activity fields', () async {
    const stamp = '2026-11-01T00:00:00.000Z';
    await repo.saveActivity(
      const ActivityRecord(
        id: 'job',
        category: Category.career,
        title: 'Engineer',
        company: 'Example',
        day: '2026-11-01',
        stage: 'interview',
        followUp: '2026-11-15',
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
    await repo.saveActivity(
      const ActivityRecord(
        id: 'workout',
        category: Category.fitness,
        title: 'Squats',
        day: '2026-11-01',
        sets: 3,
        reps: 12,
        minutes: 20,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
    await repo.saveActivity(
      const ActivityRecord(
        id: 'care',
        category: Category.personalCare,
        title: 'Hair wash',
        day: '2026-11-01',
        notes: 'Product and observations',
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
    final saved = (await repo.load()).activities;
    expect(saved.firstWhere((a) => a.id == 'job').followUp, '2026-11-15');
    expect(saved.firstWhere((a) => a.id == 'workout').reps, 12);
    expect(
      saved.firstWhere((a) => a.id == 'care').notes,
      'Product and observations',
    );
  });
  test(
    'backup round trip merges idempotently and retains newer local edits',
    () async {
      await repo.saveTask(task('a', '2026-11-02'));
      await repo.saveActivity(study('s', '2026-11-02', 60));
      final backup = await repo.exportBackup();
      final newer = task('a', '2026-11-03').toJson()
        ..['updatedAt'] = '2026-11-04T00:00:00.000Z';
      await repo.saveTask(TaskRecord.fromJson(newer));
      await repo.importBackup(backup);
      await repo.importBackup(backup);
      expect((await repo.load()).tasks.single.day, '2026-11-03');
      await repo.deleteTask('a');
      await repo.deleteActivity('s');
      await repo.importBackup(backup);
      expect((await repo.load()).tasks, isEmpty);
      expect((await repo.load()).activities, isEmpty);
      final restored = await LifeRepository.open(
        '${directory.path}/restored.db',
      );
      try {
        await restored.importBackup(backup);
        expect((await restored.load()).tasks.single.day, '2026-11-02');
        expect((await restored.load()).activities.single.minutes, 60);
        await restored.importBackup(await repo.exportBackup());
        expect((await restored.load()).tasks, isEmpty);
      } finally {
        await restored.close();
      }
    },
  );
  test('malformed backup is rejected before any records change', () async {
    await repo.saveTask(task('original', '2026-11-02'));
    final backup =
        jsonDecode(await repo.exportBackup()) as Map<String, dynamic>;
    backup['tasks'] = [
      task('new', '2026-11-02').toJson(),
      {'id': 'invalid'},
    ];
    await expectLater(repo.importBackup(jsonEncode(backup)), throwsA(anything));
    expect((await repo.load()).tasks.single.id, 'original');
  });
  test(
    'oversized imported notes cannot add records before rejection',
    () async {
      await repo.saveTask(task('original', '2026-11-02'));
      final backup =
          jsonDecode(await repo.exportBackup()) as Map<String, dynamic>;
      final oversized = task('large', '2026-11-02').toJson()
        ..['notes'] = List.filled(10001, 'x').join();
      backup['tasks'] = [task('new', '2026-11-02').toJson(), oversized];
      await expectLater(
        repo.importBackup(jsonEncode(backup)),
        throwsFormatException,
      );
      expect((await repo.load()).tasks.single.id, 'original');
    },
  );
  test('newer imported record wins and preferences remain local', () async {
    await repo.saveTask(task('a', '2026-11-02'));
    final backup =
        jsonDecode(await repo.exportBackup()) as Map<String, dynamic>;
    (backup['tasks'] as List).first['title'] = 'Updated on phone';
    (backup['tasks'] as List).first['updatedAt'] = '2026-11-04T00:00:00.000Z';
    backup['preferences'] = {'zone': 'Etc/UTC', 'theme': 'dark'};
    await repo.importBackup(jsonEncode(backup));
    final saved = await repo.load();
    expect(saved.tasks.single.title, 'Updated on phone');
    expect(saved.preferences.zone, 'Asia/Kolkata');
  });

  test(
    'completing a recurring task creates one next occurrence atomically',
    () async {
      final first = task('series', '2026-12-31', done: true).toJson()
        ..['repeat'] = 'daily';
      await repo.completeTask(TaskRecord.fromJson(first));
      await repo.completeTask(TaskRecord.fromJson(first));
      final tasks = (await repo.load()).tasks;
      expect(tasks.length, 2);
      final next = tasks.singleWhere((t) => t.day == '2027-01-01');
      expect(next.done, isFalse);
      expect(next.seriesId, 'series');
      final completed = next.toJson()
        ..['completedAt'] = '2027-01-01T12:00:00.000Z';
      await repo.completeTask(TaskRecord.fromJson(completed));
      expect(
        (await repo.load()).tasks.singleWhere((t) => t.day == '2027-01-02').id,
        'repeat-series-2027-01-02',
      );
    },
  );
  test('career history is appended by the repository, including a return to a stage', () async {
    const stamp = '2026-11-01T00:00:00.000Z';
    const application = ActivityRecord(
      id: 'job',
      category: Category.career,
      title: 'Engineer',
      company: 'Example',
      day: '2026-11-01',
      stage: 'applied',
      createdAt: stamp,
      updatedAt: stamp,
    );
    await repo.saveActivity(application);
    await repo.saveActivity(
      ActivityRecord.fromJson(application.toJson()..['stage'] = 'interview'),
    );
    await repo.saveActivity(application);
    expect(
      (await repo.load()).activities.single.events.map((e) => e['stage']),
      ['applied', 'interview', 'applied'],
    );
  });
  test('entries survive reopening and backup restore', () async {
    const stamp = '2026-11-01T00:00:00.000Z';
    const goal = LocalEntry(
      id: 'goal',
      kind: EntryKind.goal,
      title: 'Read',
      category: Category.learning,
      day: '2026-11-01',
      createdAt: stamp,
      updatedAt: stamp,
      values: {
        'unit': 'hours',
        'target': '20',
        'current': '2',
        'status': 'active',
      },
    );
    await repo.saveEntry(goal);
    await repo.close();
    repo = await LifeRepository.open(path);
    expect((await repo.load()).entries.single.number('target'), 20);
    final other = await LifeRepository.open('${directory.path}/other.db');
    try {
      await other.importBackup(await repo.exportBackup());
      expect((await other.load()).entries.single.id, 'goal');
    } finally {
      await other.close();
    }
  });
  test('schema version 1 upgrades without losing tasks', () async {
    final legacyPath = '${directory.path}/legacy.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE tasks (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE activities (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE preferences (id INTEGER PRIMARY KEY CHECK (id = 1), payload TEXT NOT NULL)',
          );
        },
      ),
    );
    await legacy.insert('tasks', {
      'id': 'legacy',
      'payload': jsonEncode(task('legacy', '2026-11-02').toJson()),
    });
    await legacy.close();
    final upgraded = await LifeRepository.open(legacyPath);
    try {
      expect((await upgraded.load()).tasks.single.id, 'legacy');
      expect(await upgraded.db.getVersion(), 2);
    } finally {
      await upgraded.close();
    }
  });

  test(
    'changing a goal target preserves its previous target history',
    () async {
      const goal = LocalEntry(
        id: 'g',
        kind: EntryKind.goal,
        title: 'Study',
        category: Category.learning,
        day: '2026-11-01',
        createdAt: '2026-11-01T00:00:00.000Z',
        updatedAt: '2026-11-01T00:00:00.000Z',
        values: {'unit': 'hours', 'target': '20', 'current': '2'},
      );
      await repo.saveEntry(goal);
      await repo.saveEntry(
        LocalEntry.fromJson(
          goal.toJson()
            ..['values'] = {'unit': 'hours', 'target': '30', 'current': '2'}
            ..['updatedAt'] = '2026-11-02T00:00:00.000Z',
        ),
      );
      expect(
        (await repo.load()).entries.single.revisions.map((r) => r['target']),
        ['20', '30'],
      );
    },
  );
  test('delete all keeps deletion protection and compaction preserves remaining data', () async {
    await repo.saveTask(task('a', '2026-11-02'));
    final backup = await repo.exportBackup();
    await repo.deleteAllRecords();
    await repo.compactStorage();
    await repo.importBackup(backup);
    expect((await repo.load()).tasks, isEmpty);
    await repo.saveTask(task('b', '2026-11-03'));
    await repo.compactStorage();
    expect((await repo.load()).tasks.single.id, 'b');
  });
}
