import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'app.dart';
import 'core/app_controller.dart';
import 'data/repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  sqfliteFfiInit();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  AppController? app;
  String? error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    LifeRepository? repository;
    try {
      final path = await PathProviderWindows().getApplicationSupportPath();
      if (path == null)
        throw StateError('Windows application storage is unavailable.');
      final directory = Directory(path);
      await directory.create(recursive: true);
      repository = await LifeRepository.open(
        '${directory.path}${Platform.pathSeparator}lifeos.db',
      );
      final controller = AppController(repository);
      await controller.initialize();
      if (mounted) {
        setState(() {
          app = controller;
          loading = false;
        });
      } else {
        controller.dispose();
        await repository.close();
      }
    } catch (e) {
      await repository?.close();
      if (mounted)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (app != null) return LifeOSApp(controller: app!);
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('LifeOS', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 24),
                if (loading)
                  const CircularProgressIndicator()
                else ...[
                  const Text(
                    'Your local database could not be opened. It has not been reset.',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(error ?? ''),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: load, child: const Text('Retry')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
