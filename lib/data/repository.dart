import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';
import '../domain/records.dart';

class Snapshot {
  const Snapshot(
    this.tasks,
    this.activities,
    this.preferences, [
    this.entries = const [],
  ]);
  final List<TaskRecord> tasks;
  final List<ActivityRecord> activities;
  final Preferences preferences;
  final List<LocalEntry> entries;
}

abstract interface class TrackerRepository {
  Future<Snapshot> load();
  Future<void> saveTask(TaskRecord task);
  Future<void> completeTask(TaskRecord task);
  Future<void> saveActivity(ActivityRecord activity);
  Future<void> saveEntry(LocalEntry entry);
  Future<void> deleteTask(String id);
  Future<void> deleteActivity(String id);
  Future<void> deleteEntry(String id);
  Future<void> deleteAllRecords();
  Future<void> compactStorage();
  Future<void> savePreferences(Preferences preferences);
  Future<String> exportBackup();
  Future<void> importBackup(String source);
}

class LifeRepository implements TrackerRepository {
  LifeRepository._(this.db);
  final Database db;
  static Future<void> _additionalSchema(Database db) async {
    await db.execute(
      'CREATE TABLE entries (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE tombstones (entity TEXT NOT NULL, id TEXT NOT NULL, updatedAt TEXT NOT NULL, PRIMARY KEY (entity, id))',
    );
  }

  static Future<LifeRepository> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final db = await (factory ?? databaseFactoryFfi).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
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
          await _additionalSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _additionalSchema(db);
        },
      ),
    );
    return LifeRepository._(db);
  }

  Future<Snapshot> load() async {
    final tasks = await db.query('tasks');
    final activities = await db.query('activities');
    final entries = await db.query('entries');
    final prefs = await db.query('preferences');
    Map<String, dynamic> decode(Map<String, Object?> r) =>
        jsonDecode(r['payload'] as String) as Map<String, dynamic>;
    return Snapshot(
      tasks.map((r) => TaskRecord.fromJson(decode(r))).toList(),
      activities.map((r) => ActivityRecord.fromJson(decode(r))).toList(),
      prefs.isEmpty ? const Preferences() : _preferences(decode(prefs.first)),
      entries.map((r) => LocalEntry.fromJson(decode(r))).toList(),
    );
  }

  static Preferences _preferences(Map<String, dynamic> value) {
    final zone = value['zone'] as String;
    tz.getLocation(zone);
    final theme = value['theme'] as String;
    if (!['system', 'light', 'dark'].contains(theme))
      throw const FormatException('Invalid theme.');
    final weekStart = value['weekStart'] as int? ?? 1;
    if (weekStart < 1 || weekStart > 7)
      throw const FormatException('Invalid start of week.');
    return Preferences(
      zone: zone,
      theme: theme,
      weekStart: weekStart,
      desktopReminders: value['desktopReminders'] as bool? ?? false,
    );
  }

  Future<void> _put(
    DatabaseExecutor executor,
    String table,
    String id,
    Map<String, Object?> value,
  ) async {
    await executor.insert(table, {
      'id': id,
      'payload': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await executor.delete(
      'tombstones',
      where: 'entity = ? AND id = ?',
      whereArgs: [table, id],
    );
  }

  Future<void> saveTask(TaskRecord task) async {
    final valid = TaskRecord.fromJson(task.toJson());
    await db.transaction((txn) => _put(txn, 'tasks', valid.id, valid.toJson()));
  }

  Future<void> completeTask(TaskRecord task) async {
    final valid = TaskRecord.fromJson(task.toJson());
    await db.transaction((txn) async {
      await _put(txn, 'tasks', valid.id, valid.toJson());
      final next = valid.nextOccurrence(
        DateTime.now().toUtc().toIso8601String(),
      );
      if (next == null) return;
      final exists = await txn.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [next.id],
      );
      final deleted = await txn.query(
        'tombstones',
        where: 'entity = ? AND id = ?',
        whereArgs: ['tasks', next.id],
      );
      if (exists.isEmpty && deleted.isEmpty)
        await _put(txn, 'tasks', next.id, next.toJson());
    });
  }

  Future<void> saveActivity(ActivityRecord activity) async {
    var valid = ActivityRecord.fromJson(activity.toJson());
    await db.transaction((txn) async {
      if (valid.category == Category.career) {
        final existing = await txn.query(
          'activities',
          where: 'id = ?',
          whereArgs: [valid.id],
        );
        final previous = existing.isEmpty
            ? null
            : ActivityRecord.fromJson(
                jsonDecode(existing.first['payload'] as String)
                    as Map<String, dynamic>,
              );
        final history = <Map<String, String>>[...?previous?.events];
        if (history.isEmpty && previous != null)
          history.add({'stage': previous.stage, 'at': previous.updatedAt});
        if (history.isEmpty || history.last['stage'] != valid.stage)
          history.add({'stage': valid.stage, 'at': valid.updatedAt});
        final value = valid.toJson()..['events'] = history;
        valid = ActivityRecord.fromJson(value);
      }
      await _put(txn, 'activities', valid.id, valid.toJson());
    });
  }

  Future<void> saveEntry(LocalEntry entry) async {
    var valid = LocalEntry.fromJson(entry.toJson());
    await db.transaction((txn) async {
      if (valid.kind == EntryKind.goal) {
        final rows = await txn.query(
          'entries',
          where: 'id = ?',
          whereArgs: [valid.id],
        );
        final previous = rows.isEmpty
            ? null
            : LocalEntry.fromJson(
                jsonDecode(rows.first['payload'] as String)
                    as Map<String, dynamic>,
              );
        final revisions = <Map<String, String>>[...?previous?.revisions];
        if (previous != null && revisions.isEmpty)
          revisions.add({
            'target': previous.text('target'),
            'unit': previous.text('unit'),
            'at': previous.updatedAt,
          });
        if (revisions.isEmpty ||
            revisions.last['target'] != valid.text('target') ||
            revisions.last['unit'] != valid.text('unit')) {
          revisions.add({
            'target': valid.text('target'),
            'unit': valid.text('unit'),
            'at': valid.updatedAt,
          });
        }
        valid = LocalEntry.fromJson(valid.toJson()..['revisions'] = revisions);
      }
      await _put(txn, 'entries', valid.id, valid.toJson());
    });
  }

  Future<void> _delete(String table, String id) => db.transaction((txn) async {
    await txn.delete(table, where: 'id = ?', whereArgs: [id]);
    await txn.insert('tombstones', {
      'entity': table,
      'id': id,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  Future<void> deleteTask(String id) => _delete('tasks', id);
  Future<void> deleteActivity(String id) => _delete('activities', id);
  Future<void> deleteEntry(String id) => _delete('entries', id);
  Future<void> savePreferences(Preferences preferences) async {
    _preferences(preferences.toJson());
    await db.insert('preferences', {
      'id': 1,
      'payload': jsonEncode(preferences.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> exportBackup() async {
    final snapshot = await load();
    return jsonEncode({
      'format': 'lifeos',
      'version': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tasks': snapshot.tasks.map((t) => t.toJson()).toList(),
      'activities': snapshot.activities.map((a) => a.toJson()).toList(),
      'entries': snapshot.entries.map((e) => e.toJson()).toList(),
      'deletions': await db.query('tombstones'),
      'preferences': snapshot.preferences.toJson(),
    });
  }

  Future<void> importBackup(String source) async {
    if (utf8.encode(source).length > 25 * 1024 * 1024)
      throw const FormatException('Backup exceeds 25 MB.');
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['format'] != 'lifeos' || ![1, 2].contains(json['version']))
      throw const FormatException('Unsupported LifeOS backup.');
    final tasks = (json['tasks'] as List)
        .map((t) => TaskRecord.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();
    final activities = (json['activities'] as List)
        .map(
          (a) => ActivityRecord.fromJson(Map<String, dynamic>.from(a as Map)),
        )
        .toList();
    final entries = (json['entries'] as List? ?? [])
        .map((e) => LocalEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final records = {
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'activities': activities.map((a) => a.toJson()).toList(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    for (final group in records.values) {
      if (group.map((r) => r['id']).toSet().length != group.length)
        throw const FormatException('Duplicate IDs.');
    }
    final deletions = (json['deletions'] as List? ?? []).map((d) {
      final row = Map<String, dynamic>.from(d as Map);
      final entity = row['entity'] as String;
      if (!records.containsKey(entity))
        throw const FormatException('Invalid deletion type.');
      return {
        'entity': entity,
        'id': requiredText(row['id'], 'ID', max: 100),
        'updatedAt': validTimestamp(row['updatedAt']),
      };
    }).toList();
    await db.transaction((txn) async {
      for (final deletion in deletions) {
        final table = deletion['entity']!, id = deletion['id']!;
        final deletedAt = DateTime.parse(deletion['updatedAt']!);
        final rows = await txn.query(table, where: 'id = ?', whereArgs: [id]);
        if (rows.isNotEmpty) {
          final local = jsonDecode(
            rows.first['payload'] as String,
          ) as Map<String, dynamic>;
          if (DateTime.parse(local['updatedAt'] as String).isAfter(deletedAt))
            continue;
        }
        final existing = await txn.query(
          'tombstones',
          where: 'entity = ? AND id = ?',
          whereArgs: [table, id],
        );
        if (existing.isNotEmpty &&
            DateTime.parse(existing.first['updatedAt'] as String)
                .isAfter(deletedAt))
          continue;
        await txn.delete(table, where: 'id = ?', whereArgs: [id]);
        await txn.insert(
          'tombstones',
          deletion,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final group in records.entries) {
        for (final record in group.value) {
          final id = record['id'] as String, table = group.key;
          final updated = DateTime.parse(record['updatedAt'] as String);
          final deleted = await txn.query(
            'tombstones',
            where: 'entity = ? AND id = ?',
            whereArgs: [table, id],
          );
          if (deleted.isNotEmpty &&
              !updated.isAfter(
                DateTime.parse(deleted.first['updatedAt'] as String),
              ))
            continue;
          final rows = await txn.query(table, where: 'id = ?', whereArgs: [id]);
          if (rows.isNotEmpty) {
            final local = jsonDecode(
              rows.first['payload'] as String,
            ) as Map<String, dynamic>;
            if (!updated.isAfter(DateTime.parse(local['updatedAt'] as String)))
              continue;
          }
          await _put(txn, table, id, record);
        }
      }
    });
  }

  Future<void> deleteAllRecords() async {
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      for (final table in ['tasks', 'activities', 'entries']) {
        final rows = await txn.query(table, columns: ['id']);
        for (final row in rows) {
          await txn.insert('tombstones', {
            'entity': table,
            'id': row['id'],
            'updatedAt': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await txn.delete(table);
      }
    });
  }

  Future<void> compactStorage() => db.execute('VACUUM');
  Future<void> close() => db.close();
}
