import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/models.dart';
import '../../ui/module_page.dart';
import '../../domain/records.dart';
import '../records/records_page.dart';

class FitnessPage extends StatelessWidget {
  const FitnessPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ModulePage(app: app, category: Category.fitness),
      RecordsPanel(
        app: app,
        kind: EntryKind.measurement,
        category: Category.fitness,
      ),
    ],
  );
}
