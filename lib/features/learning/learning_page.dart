import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/models.dart';
import '../../ui/module_page.dart';
import '../../domain/records.dart';
import '../records/records_page.dart';
import 'study_timer.dart';

class LearningPage extends StatelessWidget {
  const LearningPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StudyTimer(app: app),
      ModulePage(app: app, category: Category.learning),
      RecordsPanel(
        app: app,
        kind: EntryKind.practice,
        category: Category.learning,
      ),
      RecordsPanel(
        app: app,
        kind: EntryKind.revision,
        category: Category.learning,
      ),
      RecordsPanel(
        app: app,
        kind: EntryKind.project,
        category: Category.learning,
      ),
    ],
  );
}
