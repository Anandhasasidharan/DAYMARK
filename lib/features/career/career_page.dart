import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/models.dart';
import '../../ui/module_page.dart';

class CareerPage extends StatelessWidget {
  const CareerPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) =>
      ModulePage(app: app, category: Category.career);
}
