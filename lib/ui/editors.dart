import 'package:material_ui/material_ui.dart';

import '../core/app_controller.dart';
import '../core/clock.dart';
import '../domain/models.dart';
import '../domain/records.dart';

Future<void> editTask(
  BuildContext context,
  AppController app, {
  TaskRecord? task,
  Category? category,
  String? day,
}) async {
  final result = await showDialog<TaskRecord>(
    context: context,
    builder: (_) => RecordEditor(
      app: app,
      task: task,
      category: category ?? task?.category ?? Category.learning,
      isTask: true,
      initialDay: day,
    ),
  );
  if (result != null) await app.run(() => app.repository.saveTask(result));
}

Future<void> editActivity(
  BuildContext context,
  AppController app,
  Category category, {
  ActivityRecord? activity,
}) async {
  final result = await showDialog<ActivityRecord>(
    context: context,
    builder: (_) => RecordEditor(
      app: app,
      activity: activity,
      category: category,
      isTask: false,
    ),
  );
  if (result != null) await app.run(() => app.repository.saveActivity(result));
}

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    required this.app,
    required this.category,
    required this.isTask,
    this.task,
    this.activity,
    this.initialDay,
  });
  final AppController app;
  final Category category;
  final bool isTask;
  final TaskRecord? task;
  final ActivityRecord? activity;
  final String? initialDay;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final form = GlobalKey<FormState>();
  late Category category;
  late final TextEditingController title,
      notes,
      day,
      minutes,
      company,
      followUp,
      sets,
      reps,
      time,
      weight,
      distance,
      url,
      contact;
  late String stage, priority, repeat, workoutType;
  String? goalId;
  String? error;
  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    category = widget.category;
    title = TextEditingController(text: widget.task?.title ?? a?.title ?? '');
    notes = TextEditingController(text: widget.task?.notes ?? a?.notes ?? '');
    day = TextEditingController(
      text:
          widget.task?.day ??
          a?.day ??
          widget.initialDay ??
          widget.app.clock.today,
    );
    minutes = TextEditingController(text: '${a?.minutes ?? 30}');
    company = TextEditingController(text: a?.company ?? '');
    followUp = TextEditingController(text: a?.followUp ?? '');
    sets = TextEditingController(text: '${a?.sets ?? 0}');
    reps = TextEditingController(text: '${a?.reps ?? 0}');
    stage = a?.stage ?? 'saved';
    workoutType = a?.workoutType ?? 'strength';
    time = TextEditingController(text: widget.task?.time ?? '');
    weight = TextEditingController(text: '${a?.weight ?? 0}');
    distance = TextEditingController(text: '${a?.distance ?? 0}');
    url = TextEditingController(text: a?.url ?? '');
    contact = TextEditingController(text: a?.contact ?? '');
    priority = widget.task?.priority ?? 'normal';
    repeat = widget.task?.repeat ?? 'none';
    goalId = widget.task?.goalId ?? a?.goalId;
    if (!widget.app.entries.any(
      (e) => e.kind == EntryKind.goal && e.id == goalId,
    ))
      goalId = null;
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      notes,
      day,
      minutes,
      company,
      followUp,
      sets,
      reps,
      time,
      weight,
      distance,
      url,
      contact,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool date = false,
    int? max,
    bool numeric = false,
    bool decimal = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: lines,
      maxLength: max,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(decimal: decimal)
          : TextInputType.text,
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty))
          return 'Required';
        if (date && value != null && value.isNotEmpty) {
          try {
            parseDay(value);
          } catch (_) {
            return 'Use YYYY-MM-DD';
          }
        }
        if (numeric &&
            (decimal
                ? double.tryParse(value ?? '') == null
                : int.tryParse(value ?? '') == null))
          return decimal ? 'Enter a number' : 'Enter a whole number';
        return null;
      },
    ),
  );
  void save() {
    if (!form.currentState!.validate()) return;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      if (widget.isTask) {
        final result = TaskRecord.fromJson(
          TaskRecord(
            id: widget.task?.id ?? newId(),
            title: title.text.trim(),
            category: category,
            day: day.text,
            notes: notes.text.trim(),
            completedAt: widget.task?.completedAt,
            time: time.text.trim(),
            priority: priority,
            repeat: repeat,
            goalId: goalId,
            seriesId: widget.task?.seriesId ?? '',
            createdAt: widget.task?.createdAt ?? now,
            updatedAt: now,
          ).toJson(),
        );
        Navigator.pop(context, result);
      } else {
        if (day.text.compareTo(widget.app.clock.today) > 0) {
          throw const FormatException(
            'Log actual activity on today or an earlier date. Use a task for future plans.',
          );
        }
        final result = ActivityRecord.fromJson(
          ActivityRecord(
            id: widget.activity?.id ?? newId(),
            category: category,
            day: day.text,
            title: title.text.trim(),
            notes: notes.text.trim(),
            minutes: [Category.learning, Category.fitness].contains(category)
                ? int.parse(minutes.text)
                : 0,
            company: company.text.trim(),
            stage: stage,
            goalId: goalId,
            url: url.text.trim(),
            contact: contact.text.trim(),
            workoutType: workoutType,
            weight: category == Category.fitness
                ? double.parse(weight.text)
                : 0,
            distance: category == Category.fitness
                ? double.parse(distance.text)
                : 0,
            followUp: followUp.text.isEmpty ? null : followUp.text,
            sets: category == Category.fitness ? int.parse(sets.text) : 0,
            reps: category == Category.fitness ? int.parse(reps.text) : 0,
            createdAt: widget.activity?.createdAt ?? now,
            updatedAt: now,
          ).toJson(),
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityTitle = switch (category) {
      Category.learning => 'Topic / subject',
      Category.career => 'Role',
      Category.fitness => 'Exercise / workout',
      Category.personalCare => 'Routine / treatment',
    };
    return AlertDialog(
      title: Text(
        widget.isTask
            ? (widget.task == null ? 'New task' : 'Edit task')
            : (widget.activity == null
                  ? 'Log ${category.label.toLowerCase()}'
                  : 'Edit activity'),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(
                  title,
                  widget.isTask ? 'Task title' : activityTitle,
                  required: true,
                  max: 200,
                ),
                if (widget.isTask)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<Category>(
                      isExpanded: true,
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: Category.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => category = value!),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: goalId ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Linked goal',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('No linked goal'),
                      ),
                      ...widget.app.entries
                          .where((e) => e.kind == EntryKind.goal)
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(
                                e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (value) => goalId = value == '' ? null : value,
                  ),
                ),
                if (widget.isTask) ...[
                  field(time, 'Scheduled time (HH:MM, optional)'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: ['low', 'normal', 'high']
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (s) => priority = s!,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: repeat,
                      decoration: const InputDecoration(
                        labelText: 'Repeat after completion',
                      ),
                      items: ['none', 'daily', 'weekly']
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (s) => repeat = s!,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Completing a repeating task creates one next occurrence. Reopening it keeps that next task.',
                    ),
                  ),
                ],
                field(
                  day,
                  widget.isTask
                      ? 'Planned date (YYYY-MM-DD)'
                      : 'Logged date (YYYY-MM-DD)',
                  required: true,
                  date: true,
                ),
                if (!widget.isTask &&
                    [Category.learning, Category.fitness].contains(category))
                  field(
                    minutes,
                    'Duration in minutes (0–1440; study: at least 1)',
                    required: true,
                    numeric: true,
                  ),
                if (!widget.isTask && category == Category.career) ...[
                  field(company, 'Company', required: true, max: 200),
                  field(url, 'Application / job link', max: 2000),
                  field(contact, 'Contact', max: 200),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Application stage',
                        border: OutlineInputBorder(),
                      ),
                      items: careerStages
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (s) => setState(() => stage = s!),
                    ),
                  ),
                  field(
                    followUp,
                    'Follow-up date (YYYY-MM-DD, optional)',
                    date: true,
                  ),
                ],
                if (!widget.isTask && category == Category.fitness) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: workoutType,
                      decoration: const InputDecoration(
                        labelText: 'Workout type',
                      ),
                      items:
                          [
                                'strength',
                                'walking',
                                'running',
                                'mobility',
                                'rest',
                                'other',
                              ]
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (s) {
                        workoutType = s!;
                        if (s == 'rest') {
                          for (final c in [
                            minutes,
                            sets,
                            reps,
                            weight,
                            distance,
                          ]) {
                            c.text = '0';
                          }
                        }
                      },
                    ),
                  ),
                  field(sets, 'Sets (0 when not applicable)', numeric: true),
                  field(
                    reps,
                    'Reps per set (0 when not applicable)',
                    numeric: true,
                  ),
                  field(
                    weight,
                    'Weight in kg (optional; 0 if unused)',
                    numeric: true,
                    decimal: true,
                  ),
                  field(
                    distance,
                    'Distance in km (optional; 0 if unused)',
                    numeric: true,
                    decimal: true,
                  ),
                ],
                field(
                  notes,
                  category == Category.personalCare
                      ? 'Observations / product / notes'
                      : 'Notes',
                  lines: 3,
                  max: 10000,
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}
