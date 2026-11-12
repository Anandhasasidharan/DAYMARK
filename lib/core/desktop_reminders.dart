import 'dart:io';

import 'package:flutter_local_notifications_windows/flutter_local_notifications_windows.dart';

class DesktopReminders {
  FlutterLocalNotificationsWindows? _plugin;
  Future<void> show(String title, String body) async {
    if (!Platform.isWindows)
      throw UnsupportedError(
        'Desktop reminders are available on Windows only.',
      );
    if (_plugin == null) {
      final plugin = FlutterLocalNotificationsWindows();
      final initialized = await plugin.initialize(
        settings: const WindowsInitializationSettings(
          appName: 'LifeOS',
          appUserModelId: 'Local.LifeOS.Personal',
          guid: 'd8285fb2-3d9e-4ce6-bf98-5cfe5c912764',
        ),
      );
      if (!initialized)
        throw StateError('Windows could not initialize reminders.');
      _plugin = plugin;
    }
    await _plugin!.show(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      title: title,
      body: body,
    );
  }

  void dispose() {
    _plugin?.dispose();
  }
}
