import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/records.dart';
import '../../ui/common.dart';
import '../../ui/editors.dart';
import '../../ui/task_list.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.app, required this.onCategory});
  final AppController app;
  final void Function(Category) onCategory;
  @override
  Widget build(BuildContext context) {
    final today = app.clock.today;
    final tasks = app.tasks.where((t) => t.day == today).toList();
    final done = tasks.where((t) => t.done).length;
    final logs = app.activities
        .where((a) => a.day == today && a.category != Category.career)
        .toList();
    final minutes = logs
        .where((a) => a.category == Category.learning)
        .fold<int>(0, (sum, a) => sum + a.minutes);
    final overdue = app.tasks
        .where((t) => t.day.compareTo(today) < 0 && !t.done)
        .toList();
    final upcoming =
        app.tasks.where((t) => t.day.compareTo(today) > 0 && !t.done).toList()
          ..sort((a, b) => a.day.compareTo(b.day));
    final followUps = app.activities
        .where(
          (a) =>
              a.category == Category.career &&
              a.followUp != null &&
              a.followUp!.compareTo(today) <= 0 &&
              !['rejected', 'withdrawn', 'offer'].contains(a.stage),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(
          'Make room for progress.',
          '$today · ${app.snapshot.preferences.zone}\nA small plan. Real activity. Your own pace.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric(context, 'Tasks completed', '$done / ${tasks.length}'),
            _metric(context, 'Study today', '$minutes min'),
            _metric(context, 'Activity logs today', '${logs.length}'),
          ],
        ),
        const SizedBox(height: 24),
        Section(
          title: 'Today’s plan',
          action: FilledButton.icon(
            onPressed: app.busy ? null : () => editTask(context, app),
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
          ),
          child: TaskList(
            app: app,
            tasks: tasks,
            empty: 'A clear day. Add the things you want to make time for.',
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: Category.values
              .map(
                (c) => SizedBox(
                  width: 240,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onCategory(c),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(categoryIcon(c)),
                            const SizedBox(height: 12),
                            Text(
                              c.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${app.tasks.where((t) => t.category == c && t.day == today && t.done).length} tasks completed today',
                            ),
                            const SizedBox(height: 8),
                            const Text('Open module →'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        Section(
          title: 'Today’s habit check-ins',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!app.entries.any(
                (e) => e.kind == EntryKind.habit && habitEligible(e, today),
              ))
                const EmptyMessage(
                  'No habits scheduled today. Add a routine in Habits.',
                ),
              ...app.entries
                  .where(
                    (e) => e.kind == EntryKind.habit && habitEligible(e, today),
                  )
                  .map((habit) {
                    final checks = app.entries.where(
                      (e) =>
                          e.kind == EntryKind.occurrence &&
                          e.text('habitId') == habit.id &&
                          e.day == today,
                    );
                    final status = checks.isEmpty
                        ? 'not logged'
                        : checks.first.text('status');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${habit.title} · $status · streak ${habitStreak(habit, app.entries, today)}',
                          ),
                          OutlinedButton(
                            onPressed: app.busy
                                ? null
                                : () =>
                                      app.setHabitStatus(habit, today, 'done'),
                            child: const Text('Done'),
                          ),
                          TextButton(
                            onPressed: app.busy
                                ? null
                                : () => app.setHabitStatus(
                                    habit,
                                    today,
                                    'skipped',
                                  ),
                            child: const Text('Skip'),
                          ),
                        ],
                      ),
                    );
                  }),
            ],
          ),
        ),
        if (overdue.isNotEmpty)
          Section(
            title: 'Earlier plans still open',
            child: TaskList(app: app, tasks: overdue),
          ),
        Section(
          title: 'Coming up',
          child: TaskList(
            app: app,
            tasks: upcoming.take(10).toList(),
            empty: 'No upcoming tasks planned.',
          ),
        ),
        if (followUps.isNotEmpty)
          Section(
            title: 'Career follow-ups due',
            child: Column(
              children: followUps
                  .map(
                    (a) => ListTile(
                      leading: const Icon(Icons.work_outline),
                      title: Text('${a.company} · ${a.title}'),
                      subtitle: Text('Follow up ${a.followUp} · ${a.stage}'),
                      onTap: () => editActivity(
                        context,
                        app,
                        Category.career,
                        activity: a,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _metric(BuildContext context, String label, String value) => SizedBox(
    width: 240,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    ),
  );
}
