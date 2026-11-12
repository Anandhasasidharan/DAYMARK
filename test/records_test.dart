import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/domain/models.dart';
import 'package:lifeos/domain/records.dart';
import 'package:lifeos/domain/export.dart';

const stamp = '2026-11-01T00:00:00.000Z';
LocalEntry habit({String status = 'active'}) => LocalEntry(
  id: 'habit',
  kind: EntryKind.habit,
  title: 'Study',
  category: Category.learning,
  day: '2026-11-02',
  createdAt: stamp,
  updatedAt: stamp,
  values: {'weekdays': '1,2,3,4,5', 'status': status, 'end': ''},
);
LocalEntry checkin(String day, String status) => LocalEntry(
  id: 'habit:$day',
  kind: EntryKind.occurrence,
  title: 'Study',
  category: Category.learning,
  day: day,
  createdAt: stamp,
  updatedAt: stamp,
  values: {'habitId': 'habit', 'status': status},
);
void main() {
  test('habit denominator excludes rest days and explicit skips', () {
    final result = habitStats(
      [
        habit(),
        checkin('2026-11-02', 'done'),
        checkin('2026-11-03', 'skipped'),
      ],
      '2026-11-02',
      '2026-11-08',
    );
    expect(result.done, 1);
    expect(result.eligible, 4);
    expect(result.skipped, 1);
    expect(result.rate, 0.25);
    expect(habitEligible(habit(), '2026-11-01'), isFalse);
    expect(habitEligible(habit(), '2026-11-07'), isFalse);
    expect(habitEligible(habit(status: 'paused'), '2026-11-02'), isFalse);
  });
  test(
    'streaks exclude rest/skipped days and leave today open for logging',
    () {
      final entries = [
        habit(),
        checkin('2026-11-02', 'done'),
        checkin('2026-11-03', 'skipped'),
        checkin('2026-11-04', 'done'),
      ];
      expect(habitStreak(habit(), entries, '2026-11-05'), 2);
      expect(
        habitStreak(habit(), entries, '2026-11-05', allowUnloggedToday: false),
        0,
      );
    },
  );
  test('invalid metrics, schedules and reminder times are rejected', () {
    final goal = LocalEntry(
      id: 'g',
      kind: EntryKind.goal,
      title: 'Goal',
      category: Category.learning,
      day: '2026-11-01',
      createdAt: stamp,
      updatedAt: stamp,
      values: {'unit': 'hours', 'target': '0'},
    );
    expect(() => LocalEntry.fromJson(goal.toJson()), throwsFormatException);
    expect(
      () => LocalEntry.fromJson(
        habit().toJson()..['values'] = {'weekdays': '1,8'},
      ),
      throwsFormatException,
    );
    expect(validTime('09:30'), isTrue);
    expect(validTime('24:00'), isFalse);
    final practice = LocalEntry(
      id: 'p',
      kind: EntryKind.practice,
      title: 'SQL',
      category: Category.learning,
      day: '2026-11-01',
      createdAt: stamp,
      updatedAt: stamp,
      values: {'attempted': '2', 'correct': '3'},
    );
    expect(() => LocalEntry.fromJson(practice.toJson()), throwsFormatException);
    expect(
      () => LocalEntry.fromJson(
        practice.toJson()..['values'] = {'attempted': '2.5', 'correct': '2'},
      ),
      throwsFormatException,
    );
  });
  test(
    'CSV quotes newlines and formula-like values without embedding photo data',
    () {
      expect(csvCell('=SUM(A1)'), '"\'=SUM(A1)"');
      expect(csvCell('A "quote"\nnext'), '"A ""quote""\nnext"');
      const photo = LocalEntry(
        id: 'photo',
        kind: EntryKind.photo,
        title: 'Photo',
        category: Category.personalCare,
        day: '2026-11-01',
        createdAt: stamp,
        updatedAt: stamp,
        values: {'image': 'secret-image-data'},
      );
      final csv = recordsCsv([], [], [photo]);
      expect(csv, contains('Photo'));
      expect(csv, isNot(contains('secret-image-data')));
    },
  );
  test('practice accuracy uses sums rather than mean of percentages', () {
    final entries = [
      for (final values in [
        {'attempted': '10', 'correct': '9'},
        {'attempted': '100', 'correct': '50'},
      ])
        LocalEntry(
          id: newId(),
          kind: EntryKind.practice,
          title: 'Practice',
          category: Category.learning,
          day: '2026-11-02',
          createdAt: stamp,
          updatedAt: stamp,
          values: values,
        ),
    ];
    final totals = rangeSummary([], [], entries, '2026-11-01', '2026-11-03');
    expect(totals['attempted'], 110);
    expect(totals['correct'], 59);
  });
}
