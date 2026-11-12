import 'dart:convert';

import '../core/clock.dart';
import 'models.dart';

enum EntryKind {
  goal,
  habit,
  occurrence,
  review,
  practice,
  project,
  revision,
  measurement,
  photo,
  reminder,
}

enum FieldKind { text, notes, number, day, choice, weekdays }

class EntryField {
  const EntryField(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.required = false,
    this.options = const [],
    this.minimum = 0,
    this.maximum = 1000000,
  });
  final String key, label;
  final FieldKind kind;
  final bool required;
  final List<String> options;
  final double minimum, maximum;
}

const entryFields = <EntryKind, List<EntryField>>{
  EntryKind.goal: [
    EntryField('unit', 'Unit (hours, questions, workouts…)', required: true),
    EntryField(
      'target',
      'Target',
      kind: FieldKind.number,
      required: true,
      minimum: 0.01,
    ),
    EntryField('current', 'Actual progress', kind: FieldKind.number),
    EntryField('due', 'Due date', kind: FieldKind.day),
    EntryField(
      'status',
      'Status',
      kind: FieldKind.choice,
      options: ['active', 'paused', 'completed'],
    ),
    EntryField('milestones', 'Milestones / next steps', kind: FieldKind.notes),
  ],
  EntryKind.habit: [
    EntryField(
      'weekdays',
      'Repeat on',
      kind: FieldKind.weekdays,
      required: true,
    ),
    EntryField('end', 'End date (optional)', kind: FieldKind.day),
    EntryField(
      'status',
      'Status',
      kind: FieldKind.choice,
      options: ['active', 'paused'],
    ),
  ],
  EntryKind.occurrence: [
    EntryField('habitId', 'Habit', required: true),
    EntryField(
      'status',
      'Status',
      kind: FieldKind.choice,
      options: ['done', 'skipped'],
      required: true,
    ),
  ],
  EntryKind.review: [
    EntryField('wins', 'Wins', kind: FieldKind.notes),
    EntryField('blockers', 'Challenges / blockers', kind: FieldKind.notes),
    EntryField('next', 'Next week’s focus', kind: FieldKind.notes),
  ],
  EntryKind.practice: [
    EntryField(
      'attempted',
      'Questions attempted',
      kind: FieldKind.number,
      required: true,
      minimum: 1,
    ),
    EntryField(
      'correct',
      'Questions correct',
      kind: FieldKind.number,
      required: true,
    ),
    EntryField(
      'score',
      'Quiz / mock score (%)',
      kind: FieldKind.number,
      maximum: 100,
    ),
  ],
  EntryKind.project: [
    EntryField(
      'status',
      'Status',
      kind: FieldKind.choice,
      options: ['planned', 'in progress', 'completed'],
    ),
    EntryField('due', 'Due date', kind: FieldKind.day),
    EntryField('milestones', 'Milestones / checklist', kind: FieldKind.notes),
  ],
  EntryKind.revision: [
    EntryField(
      'status',
      'Status',
      kind: FieldKind.choice,
      options: ['pending', 'done'],
    ),
    EntryField('source', 'Reference / resource'),
  ],
  EntryKind.measurement: [
    EntryField('value', 'Measurement', kind: FieldKind.number, required: true),
    EntryField('unit', 'Unit (kg, cm, etc.)', required: true),
  ],
  EntryKind.photo: [],
  EntryKind.reminder: [
    EntryField('time', 'Time (HH:MM)', required: true),
    EntryField(
      'status',
      'Status',
      kind: FieldKind.choice,
      options: ['enabled', 'disabled', 'delivered'],
    ),
  ],
};
const entryLabels = <EntryKind, String>{
  EntryKind.goal: 'Goal',
  EntryKind.habit: 'Habit',
  EntryKind.occurrence: 'Check-in',
  EntryKind.review: 'Weekly review',
  EntryKind.practice: 'Practice result',
  EntryKind.project: 'Project',
  EntryKind.revision: 'Revision',
  EntryKind.measurement: 'Body measurement',
  EntryKind.photo: 'Progress photo',
  EntryKind.reminder: 'Reminder',
};

bool validTime(String text) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text);

class LocalEntry {
  const LocalEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.day,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.values = const {},
    this.revisions = const [],
  });
  final String id, title, day, notes, createdAt, updatedAt;
  final EntryKind kind;
  final Category category;
  final Map<String, String> values;
  final List<Map<String, String>> revisions;
  String text(String key) => values[key] ?? '';
  double number(String key) => double.tryParse(text(key)) ?? 0;
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'category': category.name,
    'day': day,
    'notes': notes,
    'values': values,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'revisions': revisions,
  };
  factory LocalEntry.fromJson(Map<String, dynamic> json) {
    final kind = EntryKind.values.byName(json['kind'] as String);
    final day = requiredText(json['day'], 'Date');
    parseDay(day);
    final source = Map<String, dynamic>.from(json['values'] as Map? ?? {});
    final values = <String, String>{};
    for (final field in entryFields[kind]!) {
      final value = optionalText(
        source[field.key],
        field.label,
        max: field.kind == FieldKind.notes ? 10000 : 200,
      );
      if (field.required && value.isEmpty)
        throw FormatException('${field.label} is required.');
      if (value.isNotEmpty) {
        switch (field.kind) {
          case FieldKind.number:
            final n = double.tryParse(value);
            if (n == null ||
                !n.isFinite ||
                n < field.minimum ||
                n > field.maximum) {
              throw FormatException(
                '${field.label} must be between ${field.minimum} and ${field.maximum}.',
              );
            }
          case FieldKind.day:
            parseDay(value);
          case FieldKind.choice:
            if (!field.options.contains(value))
              throw FormatException('Invalid ${field.label}.');
          case FieldKind.weekdays:
            final days = value.split(',').map(int.tryParse).toList();
            if (days.any((d) => d == null || d < 1 || d > 7) ||
                days.toSet().length != days.length) {
              throw const FormatException('Choose valid weekdays.');
            }
          case FieldKind.text:
          case FieldKind.notes:
            break;
        }
      }
      values[field.key] = value;
    }
    if (kind == EntryKind.practice &&
        (double.parse(values['correct']!) >
                double.parse(values['attempted']!) ||
            double.parse(values['attempted']!) % 1 != 0 ||
            double.parse(values['correct']!) % 1 != 0)) {
      throw const FormatException(
        'Question counts must be whole numbers; correct cannot exceed attempted.',
      );
    }
    if (kind == EntryKind.reminder && !validTime(values['time']!)) {
      throw const FormatException('Use a valid 24-hour time (HH:MM).');
    }
    if (kind == EntryKind.habit &&
        values['end']!.isNotEmpty &&
        values['end']!.compareTo(day) < 0) {
      throw const FormatException('Habit end must not precede start.');
    }
    if (kind == EntryKind.photo) {
      final data = requiredText(source['image'], 'Photo', max: 560000);
      final bytes = base64Decode(data);
      const png = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < 24 ||
          List.generate(8, (i) => bytes[i] == png[i]).contains(false)) {
        throw const FormatException('Invalid photo thumbnail.');
      }
      int dimension(int offset) =>
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      if (dimension(16) < 1 ||
          dimension(20) < 1 ||
          dimension(16) > 320 ||
          dimension(20) > 320) {
        throw const FormatException(
          'Photo thumbnail must fit within 320 × 320.',
        );
      }
      values['image'] = data;
    }
    final revisions = (json['revisions'] as List? ?? []).map((r) {
      final row = Map<String, dynamic>.from(r as Map);
      final target = requiredText(row['target'], 'Historical target', max: 200);
      final value = double.tryParse(target);
      if (value == null || !value.isFinite || value <= 0)
        throw const FormatException('Invalid historical target.');
      return {
        'target': target,
        'unit': requiredText(row['unit'], 'Historical unit', max: 200),
        'at': validTimestamp(row['at']),
      };
    }).toList();
    return LocalEntry(
      id: requiredText(json['id'], 'ID', max: 100),
      kind: kind,
      title: requiredText(json['title'], 'Title', max: 200),
      category: Category.values.byName(json['category'] as String),
      day: day,
      notes: optionalText(json['notes'], 'Notes'),
      values: Map.unmodifiable(values),
      revisions: List.unmodifiable(revisions),
      createdAt: validTimestamp(json['createdAt']),
      updatedAt: validTimestamp(json['updatedAt']),
    );
  }
}

bool habitEligible(LocalEntry habit, String day) =>
    habit.kind == EntryKind.habit &&
    habit.text('status') != 'paused' &&
    day.compareTo(habit.day) >= 0 &&
    (habit.text('end').isEmpty || day.compareTo(habit.text('end')) <= 0) &&
    habit.text('weekdays').split(',').contains('${parseDay(day).weekday}');

class HabitStats {
  const HabitStats(this.done, this.eligible, this.skipped);
  final int done, eligible, skipped;
  double? get rate => eligible == 0 ? null : done / eligible;
}

HabitStats habitStats(List<LocalEntry> entries, String start, String end) {
  int done = 0, eligible = 0, skipped = 0;
  final habits = entries.where((e) => e.kind == EntryKind.habit);
  final checkins = {
    for (final e in entries.where((e) => e.kind == EntryKind.occurrence))
      '${e.text('habitId')}:${e.day}': e,
  };
  var day = parseDay(start);
  final last = parseDay(end);
  while (!day.isAfter(last)) {
    final key = dateKey(day);
    for (final habit in habits) {
      if (!habitEligible(habit, key)) continue;
      final check = checkins['${habit.id}:$key'];
      if (check?.text('status') == 'skipped') {
        skipped++;
        continue;
      }
      eligible++;
      if (check?.text('status') == 'done') done++;
    }
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return HabitStats(done, eligible, skipped);
}

int habitStreak(
  LocalEntry habit,
  List<LocalEntry> entries,
  String through, {
  bool allowUnloggedToday = true,
}) {
  if (habit.text('status') == 'paused') return 0;
  final checkins = {
    for (final e in entries.where(
      (e) => e.kind == EntryKind.occurrence && e.text('habitId') == habit.id,
    ))
      e.day: e.text('status'),
  };
  var cursor = parseDay(through);
  final first = parseDay(habit.day);
  var count = 0;
  while (!cursor.isBefore(first)) {
    final key = dateKey(cursor);
    if (habitEligible(habit, key)) {
      final status = checkins[key];
      if (status == 'done') {
        count++;
      } else if (status != 'skipped' &&
          !(key == through && allowUnloggedToday)) {
        break;
      }
    }
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return count;
}
