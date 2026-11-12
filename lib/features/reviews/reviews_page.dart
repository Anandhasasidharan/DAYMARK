import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../core/clock.dart';
import '../../domain/records.dart';
import '../../domain/export.dart';
import '../../ui/common.dart';
import '../records/records_page.dart';

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final today = parseDay(app.clock.today);
    final end = dateKey(today);
    final start = dateKey(
      DateTime(
        today.year,
        today.month,
        today.day -
            (today.weekday - app.snapshot.preferences.weekStart + 7) % 7,
      ),
    );
    final totals = rangeSummary(
      app.tasks,
      app.activities,
      app.entries,
      start,
      end,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          'Weekly review',
          'Record wins, obstacles, and what to make room for next.',
        ),
        Section(
          title: 'This week so far · $start to $end',
          child: Text(
            'Study: ${totals['studyMinutes']} minutes\nTasks: ${totals['completed']} / ${totals['planned']} completed\n'
            'Workout logs (excluding rest days): ${totals['workouts']}\nCare logs: ${totals['careLogs']}\n'
            'Practice: ${totals['correct']} correct / ${totals['attempted']} attempted\n\nThese are saved measurements, not an automatic judgment of your week.',
          ),
        ),
        RecordsPanel(app: app, kind: EntryKind.review),
      ],
    );
  }
}
