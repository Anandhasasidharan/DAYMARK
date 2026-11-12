import 'package:material_ui/material_ui.dart';

import '../core/app_controller.dart';
import '../domain/models.dart';
import 'common.dart';
import 'editors.dart';
import 'task_list.dart';

class ModulePage extends StatefulWidget {
  const ModulePage({super.key, required this.app, required this.category});
  final AppController app;
  final Category category;
  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  int visible = 25;
  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final category = widget.category;
    final tasks = app.tasks.where((t) => t.category == category).toList();
    final logs = app.activities.where((a) => a.category == category).toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    final subtitle = switch (category) {
      Category.learning => 'Track time spent learning, one session at a time.',
      Category.career => 'Keep applications and next actions in one place.',
      Category.fitness => 'Record movement, workouts, and rest days.',
      Category.personalCare => 'A private record of routines and observations.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(category.label, subtitle),
        Section(
          title: 'Tasks',
          action: OutlinedButton.icon(
            onPressed: app.busy
                ? null
                : () => editTask(context, app, category: category),
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
          ),
          child: TaskList(app: app, tasks: tasks),
        ),
        Section(
          title: category == Category.career
              ? 'Applications'
              : 'Activity history',
          action: FilledButton.icon(
            onPressed: app.busy
                ? null
                : () => editActivity(context, app, category),
            icon: const Icon(Icons.add),
            label: Text(
              category == Category.career ? 'Add application' : 'Log activity',
            ),
          ),
          child: logs.isEmpty
              ? const EmptyMessage(
                  'Nothing logged yet. Start with your first entry.',
                )
              : Column(
                  children: [
                    ...logs
                        .take(visible)
                        .map(
                          (a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(categoryIcon(category)),
                            isThreeLine: a.notes.isNotEmpty,
                            title: Text(
                              category == Category.career
                                  ? '${a.company} · ${a.title}'
                                  : a.title,
                            ),
                            subtitle: Text(
                              '${_details(a)}${a.notes.isEmpty ? '' : '\n${a.notes}'}',
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Options for ${a.title}',
                              enabled: !app.busy,
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                if (category == Category.career)
                                  const PopupMenuItem(
                                    value: 'history',
                                    child: Text('Stage history'),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                              onSelected: (value) async {
                                if (value == 'edit')
                                  await editActivity(
                                    context,
                                    app,
                                    category,
                                    activity: a,
                                  );
                                if (value == 'history' && context.mounted) {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        '${a.company} · Stage history',
                                      ),
                                      content: SizedBox(
                                        width: 480,
                                        child: SingleChildScrollView(
                                          child: SelectableText(
                                            a.events.isEmpty
                                                ? 'No recorded stage history yet.'
                                                : a.events
                                                      .map(
                                                        (e) =>
                                                            '${e['stage']} · ${app.clock.localStamp(e['at']!)}',
                                                      )
                                                      .join('\n'),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                if (value == 'delete' &&
                                    await confirmDelete(context, a.title)) {
                                  await app.run(
                                    () => app.repository.deleteActivity(a.id),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                    if (logs.length > visible)
                      TextButton(
                        onPressed: () => setState(() => visible += 25),
                        child: Text(
                          'Show more (${logs.length - visible} remaining)',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String _details(ActivityRecord a) => switch (widget.category) {
    Category.learning => '${a.day} · ${a.minutes} min',
    Category.career =>
      '${a.day} · ${a.stage}${a.followUp == null ? '' : ' · Follow up ${a.followUp}'}',
    Category.fitness =>
      '${a.day} · ${a.workoutType} · ${a.minutes} min · ${a.sets} sets × ${a.reps} reps · ${a.weight} kg · ${a.distance} km',
    Category.personalCare => a.day,
  };
}
