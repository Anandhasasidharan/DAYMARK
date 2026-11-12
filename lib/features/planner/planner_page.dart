import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../core/clock.dart';
import '../../domain/records.dart';
import '../../ui/common.dart';
import '../../ui/editors.dart';
import '../../ui/task_list.dart';
import '../records/records_page.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key, required this.app});
  final AppController app;
  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  late String day;
  String search = '', status = 'all';
  @override
  void initState() {
    super.initState();
    day = widget.app.clock.today;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.app.tasks
        .where(
          (t) =>
              t.day == day &&
              (status == 'all' || (status == 'completed' ? t.done : !t.done)) &&
              '${t.title} ${t.notes}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          'Daily planner',
          'Choose a day, plan time, reschedule, and record what you actually completed.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous day',
              onPressed: () => shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parseDay(day),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => day = dateKey(picked));
              },
              child: Text(day),
            ),
            IconButton(
              tooltip: 'Next day',
              onPressed: () => shift(1),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () => setState(() => day = widget.app.clock.today),
              child: const Text('Today'),
            ),
            FilledButton.icon(
              onPressed: widget.app.busy
                  ? null
                  : () => editTask(context, widget.app, day: day),
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search this day’s tasks',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => search = value),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All')),
            ButtonSegment(value: 'planned', label: Text('Planned')),
            ButtonSegment(value: 'completed', label: Text('Completed')),
          ],
          selected: {status},
          onSelectionChanged: (value) => setState(() => status = value.first),
        ),
        const SizedBox(height: 16),
        Section(
          title: '$day · ${tasks.length} tasks',
          child: TaskList(app: widget.app, tasks: tasks),
        ),
        const Text(
          'Use a reminder below for a desktop alert. LifeOS must remain open; Windows notification settings can suppress alerts.',
        ),
        const SizedBox(height: 16),
        RecordsPanel(app: widget.app, kind: EntryKind.reminder),
      ],
    );
  }

  void shift(int offset) {
    final date = parseDay(day);
    setState(
      () => day = dateKey(DateTime(date.year, date.month, date.day + offset)),
    );
  }
}
