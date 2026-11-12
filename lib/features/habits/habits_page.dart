import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/records.dart';
import '../../core/clock.dart';
import '../../ui/common.dart';
import '../../ui/entry_editor.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key, required this.app});
  final AppController app;
  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  late String day;
  @override
  void initState() {
    super.initState();
    day = widget.app.clock.today;
  }

  Future<void> check(LocalEntry habit, String? status) async {
    await widget.app.setHabitStatus(habit, day, status);
  }

  @override
  Widget build(BuildContext context) {
    final habits = widget.app.entries
        .where((e) => e.kind == EntryKind.habit)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          'Habits & routines',
          'A check-in takes seconds. Skipped days are excluded; an empty day means not logged.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate: parseDay(day),
                  firstDate: DateTime(2000),
                  lastDate: parseDay(widget.app.clock.today),
                );
                if (value != null) setState(() => day = dateKey(value));
              },
              child: Text(day),
            ),
            FilledButton.icon(
              onPressed: widget.app.busy
                  ? null
                  : () => editEntry(context, widget.app, EntryKind.habit),
              icon: const Icon(Icons.add),
              label: const Text('Add habit'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (habits.isEmpty)
          const EmptyMessage('Add a recurring habit or care routine to begin.'),
        ...habits.map((habit) {
          final matches = widget.app.entries.where(
            (e) =>
                e.kind == EntryKind.occurrence &&
                e.text('habitId') == habit.id &&
                e.day == day,
          );
          final status = matches.isEmpty
              ? 'not logged'
              : matches.first.text('status');
          final eligible = habitEligible(habit, day);
          return Section(
            title: habit.title,
            action: PopupMenuButton<String>(
              enabled: !widget.app.busy,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit / pause')),
                PopupMenuItem(value: 'delete', child: Text('Delete habit')),
              ],
              onSelected: (value) async {
                if (value == 'edit')
                  await editEntry(
                    context,
                    widget.app,
                    EntryKind.habit,
                    entry: habit,
                  );
                if (value == 'delete' &&
                    await confirmDelete(context, habit.title))
                  await widget.app.run(
                    () => widget.app.repository.deleteEntry(habit.id),
                  );
              },
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${habit.category.label} · ${eligible ? 'Scheduled today' : 'Not scheduled / paused'} · $status',
                ),
                Text(
                  'Streak: ${habitStreak(habit, widget.app.entries, day, allowUnloggedToday: day == widget.app.clock.today)} scheduled check-ins · skips and rest days excluded',
                ),
                if (habit.notes.isNotEmpty) Text(habit.notes),
                if (eligible)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: widget.app.busy
                            ? null
                            : () => check(habit, 'done'),
                        child: const Text('Done'),
                      ),
                      OutlinedButton(
                        onPressed: widget.app.busy
                            ? null
                            : () => check(habit, 'skipped'),
                        child: const Text('Skip'),
                      ),
                      if (status != 'not logged')
                        TextButton(
                          onPressed: widget.app.busy
                              ? null
                              : () => check(habit, null),
                          child: const Text('Clear check-in'),
                        ),
                    ],
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
