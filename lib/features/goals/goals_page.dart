import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/records.dart';
import '../../ui/common.dart';
import '../records/records_page.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'Goals & projects',
        'Set a measurable target, record actual progress, and keep the next steps visible.',
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text(
          'Goal progress is entered explicitly. Linked tasks and sessions add context; completing a task never guesses your measurements.',
        ),
      ),
      RecordsPanel(app: app, kind: EntryKind.goal),
      RecordsPanel(app: app, kind: EntryKind.project),
    ],
  );
}
