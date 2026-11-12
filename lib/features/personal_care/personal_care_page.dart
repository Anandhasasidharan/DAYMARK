import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/models.dart';
import '../../ui/module_page.dart';
import '../../domain/records.dart';
import '../records/records_page.dart';

class PersonalCarePage extends StatelessWidget {
  const PersonalCarePage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ModulePage(app: app, category: Category.personalCare),
      RecordsPanel(
        app: app,
        kind: EntryKind.photo,
        category: Category.personalCare,
      ),
    ],
  );
}
