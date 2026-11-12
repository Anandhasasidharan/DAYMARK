import 'package:material_ui/material_ui.dart';

import '../core/app_controller.dart';
import '../core/clock.dart';
import '../domain/models.dart';
import 'common.dart';
import 'editors.dart';

class TaskList extends StatefulWidget {
  const TaskList({
    super.key,
    required this.app,
    required this.tasks,
    this.empty = 'No tasks yet. Add a task to start planning.',
  });
  final AppController app;
  final List<TaskRecord> tasks;
  final String empty;
  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  int visible = 25;
  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final tasks = widget.tasks;
    final empty = widget.empty;
    if (tasks.isEmpty) return EmptyMessage(empty);
    final sorted = [...tasks]
      ..sort((a, b) {
        final date = a.day.compareTo(b.day);
        if (date != 0) return date;
        final time = a.time.compareTo(b.time);
        return time != 0 ? time : a.title.compareTo(b.title);
      });
    return Column(
      children: [
        ...sorted
            .take(visible)
            .map(
              (task) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: task.done,
                      semanticLabel: 'Complete ${task.title}',
                      onChanged: app.busy ? null : (_) => app.toggle(task),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: task.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              '${task.category.label} · ${task.day}${task.time.isEmpty ? '' : ' ${task.time}'} · ${task.priority} · ${task.done ? 'Completed' : 'Planned'}${task.repeat == 'none' ? '' : ' · ${task.repeat}'}',
                            ),
                            if (task.notes.isNotEmpty) Text(task.notes),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !app.busy,
                      tooltip: 'Options for ${task.title}',
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await editTask(context, app, task: task);
                        }
                        if (value == 'snooze') {
                          final now = app.clock.now;
                          final day = dateKey(
                            DateTime(now.year, now.month, now.day + 1),
                          );
                          final value = task.toJson()
                            ..['day'] = day
                            ..['updatedAt'] = DateTime.now()
                                .toUtc()
                                .toIso8601String();
                          await app.run(
                            () => app.repository.saveTask(
                              TaskRecord.fromJson(value),
                            ),
                          );
                        }
                        if (value == 'delete' &&
                            await confirmDelete(context, task.title)) {
                          await app.run(
                            () => app.repository.deleteTask(task.id),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit / reschedule'),
                        ),
                        PopupMenuItem(
                          value: 'snooze',
                          child: Text('Move to tomorrow'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        if (sorted.length > visible)
          TextButton(
            onPressed: () => setState(() => visible += 25),
            child: Text('Show more (${sorted.length - visible} remaining)'),
          ),
      ],
    );
  }
}
