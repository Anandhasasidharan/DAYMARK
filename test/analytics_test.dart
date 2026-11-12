import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/clock.dart';
import 'package:lifeos/domain/analytics.dart';
import 'package:lifeos/domain/models.dart';
import 'package:timezone/data/latest.dart' as tz_data;

const stamp = '2026-11-01T00:00:00.000Z';
TaskRecord task(String id, String day, {bool done = false}) => TaskRecord(
  id: id,
  title: id,
  category: Category.learning,
  day: day,
  createdAt: stamp,
  updatedAt: stamp,
  completedAt: done ? stamp : null,
);
ActivityRecord study(String id, String day, int minutes) => ActivityRecord(
  id: id,
  category: Category.learning,
  day: day,
  title: 'SQL',
  minutes: minutes,
  createdAt: stamp,
  updatedAt: stamp,
);

void main() {
  setUpAll(tz_data.initializeTimeZones);
  test('aggregates study sessions and task completion by recorded day', () {
    final result = dailyMetrics(
      [
        task('a', '2026-11-02', done: true),
        task('b', '2026-11-02'),
        task('outside', '2026-11-01', done: true),
      ],
      [
        study('1', '2026-11-02', 25),
        study('2', '2026-11-02', 35),
        study('outside', '2026-11-01', 100),
      ],
      '2026-11-03',
      2,
    );
    expect(result.first.studyMinutes, 60);
    expect(result.first.planned, 2);
    expect(result.first.completed, 1);
    expect(result.first.completionRate, 0.5);
    expect(result.last.studyMinutes, 0);
    expect(result.last.completionRate, isNull);
  });
  test('day range crosses year boundary without dropping empty days', () {
    final result = dailyMetrics([], [], '2027-01-02', 3);
    expect(result.map((m) => m.day), [
      '2026-12-31',
      '2027-01-01',
      '2027-01-02',
    ]);
  });
  test('Kolkata day is independent of the device time zone', () {
    final clock = AppClock(
      'Asia/Kolkata',
      now: () => DateTime.utc(2026, 11, 10, 20),
    );
    expect(clock.today, '2026-11-11');
    expect(
      AppClock(
        'America/New_York',
        now: () => DateTime.utc(2026, 7, 1, 2),
      ).today,
      '2026-06-30',
    );
  });
  test('imported notes and hidden company fields obey storage limits', () {
    final longNotes = List.filled(10001, 'x').join();
    final longCompany = List.filled(201, 'x').join();
    expect(
      () => TaskRecord.fromJson(
        task('a', '2026-11-02').toJson()..['notes'] = longNotes,
      ),
      throwsFormatException,
    );
    expect(
      () => ActivityRecord.fromJson(
        study('s', '2026-11-02', 10).toJson()..['notes'] = longNotes,
      ),
      throwsFormatException,
    );
    expect(
      () => ActivityRecord.fromJson(
        study('s', '2026-11-02', 10).toJson()..['company'] = longCompany,
      ),
      throwsFormatException,
    );
    final boundary = List.filled(10000, 'x').join();
    expect(
      TaskRecord.fromJson(
        task('b', '2026-11-02').toJson()..['notes'] = boundary,
      ).notes.length,
      10000,
    );
  });
  test('invalid date and activity duration are rejected', () {
    expect(() => parseDay('2026-02-30'), throwsFormatException);
    expect(
      () => ActivityRecord.fromJson(study('bad', '2026-11-02', 0).toJson()),
      throwsFormatException,
    );
    expect(
      () => ActivityRecord.fromJson(study('bad', '2026-11-02', -1).toJson()),
      throwsFormatException,
    );
  });
}
