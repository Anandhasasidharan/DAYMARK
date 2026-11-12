import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/analytics.dart';
import '../../ui/common.dart';
import '../../core/clock.dart';
import '../../domain/export.dart';
import '../../domain/models.dart';
import '../../domain/records.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.app});
  final AppController app;
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int days = 7;
  String? rangeEnd;
  @override
  Widget build(BuildContext context) {
    final metrics = dailyMetrics(
      widget.app.tasks,
      widget.app.activities,
      rangeEnd ?? widget.app.clock.today,
      days,
    );
    final start = metrics.first.day, end = metrics.last.day;
    final totals = rangeSummary(
      widget.app.tasks,
      widget.app.activities,
      widget.app.entries,
      start,
      end,
    );
    final habits = habitStats(widget.app.entries, start, end);
    final applications = widget.app.activities
        .where(
          (a) =>
              a.category == Category.career &&
              a.day.compareTo(start) >= 0 &&
              a.day.compareTo(end) <= 0,
        )
        .toList();
    final total = metrics.fold<int>(0, (sum, m) => sum + m.studyMinutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          'Progress you can see.',
          'Measurements from your saved records. No scores, no guesses.',
        ),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
          ],
          selected: {days == 7 ? 7 : 30},
          onSelectionChanged: (values) => setState(() {
            days = values.first;
            rangeEnd = null;
          }),
        ),
        TextButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: parseDay(widget.app.clock.today),
            );
            if (picked == null || !context.mounted) return;
            final first = DateTime.utc(
              picked.start.year,
              picked.start.month,
              picked.start.day,
            );
            final last = DateTime.utc(
              picked.end.year,
              picked.end.month,
              picked.end.day,
            );
            final length = last.difference(first).inDays + 1;
            if (length > 366) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Choose up to 366 days.')),
              );
              return;
            }
            setState(() {
              days = length;
              rangeEnd = dateKey(picked.end);
            });
          },
          icon: const Icon(Icons.date_range),
          label: const Text('Custom range (up to 366 days)'),
        ),
        const SizedBox(height: 20),
        Text(
          '${metrics.first.day} to ${metrics.last.day} · ${widget.app.snapshot.preferences.zone}',
        ),
        const SizedBox(height: 20),
        Section(
          title: 'Study time · $total minutes',
          child: MetricChart(metrics: metrics, study: true),
        ),
        Section(
          title: 'Daily tasks · completed / planned',
          child: MetricChart(metrics: metrics, study: false),
        ),
        Section(
          title: 'Workout frequency · completed logs per day',
          child: MetricChart(
            metrics: metrics
                .map(
                  (m) => DayMetrics(
                    m.day,
                    widget.app.activities
                        .where(
                          (a) =>
                              a.day == m.day &&
                              a.category == Category.fitness &&
                              a.workoutType != 'rest',
                        )
                        .length,
                    0,
                    0,
                  ),
                )
                .toList(),
            study: true,
            unit: 'logs',
            explanation: 'Count of recorded workout entries per date; rest days are excluded. Multiple exercise entries count separately.',
          ),
        ),
        Section(
          title: 'Personal-care routine adherence',
          child: MetricChart(
            metrics: metrics.map((m) {
              final stats = habitStats(
                widget.app.entries
                    .where(
                      (e) =>
                          e.kind == EntryKind.occurrence ||
                          e.category == Category.personalCare,
                    )
                    .toList(),
                m.day,
                m.day,
              );
              return DayMetrics(m.day, 0, stats.eligible, stats.done);
            }).toList(),
            study: false,
            explanation: 'Completed / eligible scheduled personal-care habit instances. Explicit skips are excluded. Light bar: scheduled; solid: completed.',
          ),
        ),
        Section(
          title: 'Activity totals',
          child: Text(
            'Workout logs excluding rest days: ${totals['workouts']}\n'
            'Personal-care logs: ${totals['careLogs']}\n'
            'Practice accuracy: ${totals['attempted'] == 0 ? 'not logged' : '${((totals['correct']! / totals['attempted']!) * 100).toStringAsFixed(1)}% (${totals['correct']} / ${totals['attempted']})'}',
          ),
        ),
        Section(
          title: 'Habit / routine adherence',
          child: Text(
            '${habits.done} completed / ${habits.eligible} eligible scheduled instances\n'
            '${habits.skipped} explicitly skipped instances excluded. Future dates excluded by the selected range.\n'
            '${habits.rate == null ? 'No scheduled habits' : '${(habits.rate! * 100).toStringAsFixed(1)}%'}\n'
            'Unlogged eligible dates remain unlogged. Editing or pausing a habit changes this calculation.',
          ),
        ),
        Section(
          title: 'Career application funnel',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${applications.length} applications recorded in this date range; distinct applications reaching each recorded stage:',
              ),
              ...careerStages.map(
                (stage) => Text(
                  '$stage: ${applications.where((a) => a.stage == stage || a.events.any((e) => e['stage'] == stage)).length}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MetricChart extends StatelessWidget {
  const MetricChart({
    super.key,
    required this.metrics,
    required this.study,
    this.unit = 'min',
    this.explanation,
  });
  final List<DayMetrics> metrics;
  final bool study;
  final String unit;
  final String? explanation;
  @override
  Widget build(BuildContext context) {
    final peak = max(
      1,
      metrics.fold<int>(
        0,
        (peak, m) => max(peak, study ? m.studyMinutes : m.planned),
      ),
    );
    final color = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          explanation ??
              (study
                  ? 'Sum of logged study minutes per date. No sessions = not logged.'
                  : 'Tasks grouped by planned date; numerator is currently completed tasks. No tasks = no plan.'),
        ),
        const SizedBox(height: 16),
        ...metrics.map((m) {
          final value = study ? m.studyMinutes : m.completed;
          final label = study
              ? (value == 0 ? 'Not logged' : '$value $unit')
              : (m.planned == 0 ? 'No plan' : '${m.completed} / ${m.planned}');
          final semantics = '${m.day}: $label';
          return Semantics(
            label: semantics,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(m.day)),
                        Text(label),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LayoutBuilder(
                      builder: (context, constraints) => SizedBox(
                        height: 14,
                        child: Stack(
                          children: [
                            Container(
                              width: constraints.maxWidth,
                              color: muted,
                            ),
                            if (!study && m.planned > 0)
                              Container(
                                width: constraints.maxWidth * m.planned / peak,
                                color: color.withValues(alpha: 0.25),
                              ),
                            Container(
                              width: constraints.maxWidth * value / peak,
                              color: color,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (!study && explanation == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Light bar: planned · Solid bar: completed. Editing a task updates this chart.',
            ),
          ),
      ],
    );
  }
}
