import 'dart:convert';

import 'models.dart';
import 'records.dart';

String csvCell(Object? value) {
  var text = value?.toString() ?? '';
  if (RegExp(r'^[\s]*[=+@-]').hasMatch(text) ||
      text.startsWith('\t') ||
      text.startsWith('\r'))
    text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

String recordsCsv(
  List<TaskRecord> tasks,
  List<ActivityRecord> activities,
  List<LocalEntry> entries,
) {
  final rows = <List<Object?>>[
    [
      'type',
      'id',
      'category',
      'title',
      'date',
      'status',
      'minutes',
      'company',
      'stage',
      'sets',
      'reps',
      'weight_kg',
      'distance_km',
      'notes',
      'details',
    ],
    ...tasks.map(
      (t) => [
        'task',
        t.id,
        t.category.label,
        t.title,
        t.day,
        t.done ? 'completed' : 'planned',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        t.notes,
        jsonEncode({
          'time': t.time,
          'priority': t.priority,
          'repeat': t.repeat,
          'goalId': t.goalId,
        }),
      ],
    ),
    ...activities.map(
      (a) => [
        'activity',
        a.id,
        a.category.label,
        a.title,
        a.day,
        'logged',
        a.minutes,
        a.company,
        a.stage,
        a.sets,
        a.reps,
        a.weight,
        a.distance,
        a.notes,
        jsonEncode({
          'contact': a.contact,
          'url': a.url,
          'followUp': a.followUp,
          'events': a.events,
          'goalId': a.goalId,
          'workoutType': a.workoutType,
        }),
      ],
    ),
    ...entries.map(
      (e) => [
        e.kind.name,
        e.id,
        e.category.label,
        e.title,
        e.day,
        e.text('status'),
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        e.notes,
        jsonEncode({...e.values}..remove('image')),
      ],
    ),
  ];
  return rows.map((row) => row.map(csvCell).join(',')).join('\r\n');
}

Map<String, num> rangeSummary(
  List<TaskRecord> tasks,
  List<ActivityRecord> activities,
  List<LocalEntry> entries,
  String start,
  String end,
) {
  bool inside(String day) =>
      day.compareTo(start) >= 0 && day.compareTo(end) <= 0;
  final selected = activities.where((a) => inside(a.day));
  final practice = entries.where(
    (e) => e.kind == EntryKind.practice && inside(e.day),
  );
  final planned = tasks.where((t) => inside(t.day));
  return {
    'studyMinutes': selected
        .where((a) => a.category == Category.learning)
        .fold<int>(0, (n, a) => n + a.minutes),
    'workouts': selected
        .where((a) => a.category == Category.fitness && a.workoutType != 'rest')
        .length,
    'careLogs': selected
        .where((a) => a.category == Category.personalCare)
        .length,
    'planned': planned.length,
    'completed': planned.where((t) => t.done).length,
    'attempted': practice.fold<double>(0, (n, e) => n + e.number('attempted')),
    'correct': practice.fold<double>(0, (n, e) => n + e.number('correct')),
  };
}
