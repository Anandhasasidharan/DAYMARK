import 'dart:math';

import '../core/clock.dart';

enum Category {
  learning('Learning'),
  career('Career'),
  fitness('Exercise'),
  personalCare('Personal Care');

  const Category(this.label);
  final String label;
}

String newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String requiredText(Object? value, String label, {int max = 10000}) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw FormatException('$label is required (maximum $max characters).');
  }
  return value.trim();
}

// Keep imported free-text fields within the same limits as the entry forms.
String optionalText(Object? value, String label, {int max = 10000}) {
  if (value == null) return '';
  if (value is! String || value.length > max) {
    throw FormatException('$label must be text (maximum $max characters).');
  }
  return value.trim();
}

String validTimestamp(Object? value) {
  final text = requiredText(value, 'Timestamp', max: 40);
  if (!text.endsWith('Z') || DateTime.tryParse(text) == null) {
    throw const FormatException('Timestamp must be UTC.');
  }
  return text;
}

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.day,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.completedAt,
    this.goalId,
    this.time = '',
    this.priority = 'normal',
    this.repeat = 'none',
    this.seriesId = '',
  });
  final String id, title, day, notes, createdAt, updatedAt;
  final Category category;
  final String? completedAt, goalId;
  final String time, priority, repeat, seriesId;
  bool get done => completedAt != null;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'day': day,
    'notes': notes,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'completedAt': completedAt,
    'goalId': goalId,
    'time': time,
    'priority': priority,
    'repeat': repeat,
    'seriesId': seriesId,
  };
  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    final day = requiredText(json['day'], 'Date');
    parseDay(day);
    final time = optionalText(json['time'], 'Time', max: 5);
    if (time.isNotEmpty &&
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      throw const FormatException('Use HH:MM for the scheduled time.');
    }
    final priority = json['priority'] as String? ?? 'normal';
    final repeat = json['repeat'] as String? ?? 'none';
    if (!['low', 'normal', 'high'].contains(priority) ||
        !['none', 'daily', 'weekly'].contains(repeat)) {
      throw const FormatException('Invalid priority or repetition.');
    }
    final id = requiredText(json['id'], 'ID', max: 100);
    final series = optionalText(json['seriesId'], 'Series ID', max: 64);
    if (repeat != 'none' && (series.isEmpty ? id : series).length > 64) {
      throw const FormatException('Repeating task series ID is too long.');
    }
    return TaskRecord(
      id: id,
      title: requiredText(json['title'], 'Title', max: 200),
      category: Category.values.byName(json['category'] as String),
      day: day,
      notes: optionalText(json['notes'], 'Notes'),
      goalId: json['goalId'] == null
          ? null
          : requiredText(json['goalId'], 'Goal ID', max: 100),
      time: time,
      priority: priority,
      repeat: repeat,
      seriesId: series,
      createdAt: validTimestamp(json['createdAt']),
      updatedAt: validTimestamp(json['updatedAt']),
      completedAt: json['completedAt'] == null
          ? null
          : validTimestamp(json['completedAt']),
    );
  }
  TaskRecord? nextOccurrence(String now) {
    if (!done || repeat == 'none') return null;
    final date = parseDay(day);
    final next = dateKey(
      DateTime(date.year, date.month, date.day + (repeat == 'daily' ? 1 : 7)),
    );
    final series = seriesId.isEmpty ? id : seriesId;
    return TaskRecord(
      id: 'repeat-$series-$next',
      title: title,
      category: category,
      day: next,
      createdAt: now,
      updatedAt: now,
      notes: notes,
      goalId: goalId,
      time: time,
      priority: priority,
      repeat: repeat,
      seriesId: series,
    );
  }
}

const careerStages = [
  'saved',
  'applied',
  'assessment',
  'interview',
  'offer',
  'rejected',
  'withdrawn',
];

/// A completed activity; a career record instead describes an application.
/// Category-specific fields are validated before entering the repository.
class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.category,
    required this.day,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.minutes = 0,
    this.company = '',
    this.stage = 'saved',
    this.followUp,
    this.sets = 0,
    this.reps = 0,
    this.weight = 0,
    this.distance = 0,
    this.url = '',
    this.contact = '',
    this.goalId,
    this.events = const [],
    this.workoutType = 'other',
  });
  final String id, day, title, notes, company, stage, createdAt, updatedAt;
  final String? followUp;
  final Category category;
  final int minutes, sets, reps;
  final double weight, distance;
  final String url, contact, workoutType;
  final String? goalId;
  final List<Map<String, String>> events;
  Map<String, Object?> toJson() => {
    'id': id,
    'category': category.name,
    'day': day,
    'title': title,
    'notes': notes,
    'minutes': minutes,
    'company': company,
    'stage': stage,
    'followUp': followUp,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'distance': distance,
    'url': url,
    'contact': contact,
    'goalId': goalId,
    'events': events,
    'workoutType': workoutType,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    final category = Category.values.byName(json['category'] as String);
    final day = requiredText(json['day'], 'Date');
    parseDay(day);
    final minutes = json['minutes'] as int? ?? 0;
    final sets = json['sets'] as int? ?? 0;
    final reps = json['reps'] as int? ?? 0;
    if (minutes < 0 ||
        minutes > 1440 ||
        sets < 0 ||
        sets > 1000 ||
        reps < 0 ||
        reps > 10000) {
      throw const FormatException(
        'Duration or exercise count is out of range.',
      );
    }
    if (category == Category.learning && minutes == 0) {
      throw const FormatException('Study duration must be 1–1440 minutes.');
    }
    final company = optionalText(json['company'], 'Company', max: 200);
    final stage = requiredText(json['stage'] ?? 'saved', 'Stage', max: 32);
    if (category == Category.career) {
      requiredText(company, 'Company', max: 200);
      if (!careerStages.contains(stage))
        throw const FormatException('Invalid application stage.');
    }
    final workoutType =
        json['workoutType'] as String? ??
        ((json['title'] as String?)?.toLowerCase() == 'rest'
            ? 'rest'
            : 'other');
    if (![
      'strength',
      'walking',
      'running',
      'mobility',
      'rest',
      'other',
    ].contains(workoutType))
      throw const FormatException('Invalid workout type.');
    final weight = (json['weight'] as num?)?.toDouble() ?? 0;
    final distance = (json['distance'] as num?)?.toDouble() ?? 0;
    if (!weight.isFinite ||
        !distance.isFinite ||
        weight < 0 ||
        weight > 10000 ||
        distance < 0 ||
        distance > 10000) {
      throw const FormatException(
        'Weight and distance must be between 0 and 10000.',
      );
    }
    final events = (json['events'] as List? ?? []).map((event) {
      final e = Map<String, dynamic>.from(event as Map);
      final stage = requiredText(e['stage'], 'History stage', max: 32);
      if (!careerStages.contains(stage))
        throw const FormatException('Invalid history stage.');
      return {'stage': stage, 'at': validTimestamp(e['at'])};
    }).toList();
    final followUp = json['followUp'] as String?;
    if (followUp != null) parseDay(followUp);
    return ActivityRecord(
      id: requiredText(json['id'], 'ID', max: 100),
      category: category,
      day: day,
      title: requiredText(json['title'], 'Activity', max: 200),
      notes: optionalText(json['notes'], 'Notes'),
      minutes: minutes,
      company: company,
      stage: stage,
      followUp: followUp,
      sets: sets,
      reps: reps,
      weight: weight,
      distance: distance,
      events: List.unmodifiable(events),
      workoutType: workoutType,
      url: optionalText(json['url'], 'Link', max: 2000),
      contact: optionalText(json['contact'], 'Contact', max: 200),
      goalId: json['goalId'] == null
          ? null
          : requiredText(json['goalId'], 'Goal ID', max: 100),
      createdAt: validTimestamp(json['createdAt']),
      updatedAt: validTimestamp(json['updatedAt']),
    );
  }
}

class Preferences {
  const Preferences({
    this.zone = 'Asia/Kolkata',
    this.theme = 'system',
    this.desktopReminders = false,
    this.weekStart = 1,
  });
  final String zone, theme;
  final bool desktopReminders;
  final int weekStart;
  Map<String, Object?> toJson() => {
    'zone': zone,
    'theme': theme,
    'desktopReminders': desktopReminders,
    'weekStart': weekStart,
  };
}
