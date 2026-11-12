import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'ui/editors.dart';
import 'features/planner/planner_page.dart';
import 'features/goals/goals_page.dart';
import 'features/habits/habits_page.dart';
import 'features/reviews/reviews_page.dart';
import 'core/app_controller.dart';
import 'domain/models.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/learning/learning_page.dart';
import 'features/career/career_page.dart';
import 'features/fitness/fitness_page.dart';
import 'features/personal_care/personal_care_page.dart';
import 'features/analytics/analytics_page.dart';
import 'features/settings/settings_page.dart';

class LifeOSApp extends StatefulWidget {
  const LifeOSApp({super.key, required this.controller});
  final AppController controller;
  @override
  State<LifeOSApp> createState() => _LifeOSAppState();
}

class _LifeOSAppState extends State<LifeOSApp> with WidgetsBindingObserver {
  int page = 0;
  Timer? timer;
  static const labels = [
    'Home',
    'Learning',
    'Career',
    'Exercise',
    'Personal Care',
    'Planner',
    'Goals & projects',
    'Habits',
    'Reviews',
    'Analytics',
    'Settings',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.auto_stories_outlined,
    Icons.work_outline,
    Icons.fitness_center,
    Icons.spa_outlined,
    Icons.calendar_month_outlined,
    Icons.flag_outlined,
    Icons.repeat,
    Icons.edit_note,
    Icons.bar_chart,
    Icons.settings_outlined,
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh day-sensitive views after midnight, including when left open.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.controller.checkReminders(),
    );
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
      widget.controller.checkReminders();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      widget.controller.checkReminders();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final app = widget.controller;
      return MaterialApp(
        title: 'LifeOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff287767)),
          scaffoldBackgroundColor: const Color(0xfff5f7f4),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff65c6ac),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: switch (app.snapshot.preferences.theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final Widget content = switch (page) {
              0 => DashboardPage(
                app: app,
                onCategory: (Category category) =>
                    setState(() => page = category.index + 1),
              ),
              1 => LearningPage(app: app),
              2 => CareerPage(app: app),
              3 => FitnessPage(app: app),
              4 => PersonalCarePage(app: app),
              5 => PlannerPage(app: app),
              6 => GoalsPage(app: app),
              7 => HabitsPage(app: app),
              8 => ReviewsPage(app: app),
              9 => AnalyticsPage(app: app),
              _ => SettingsPage(app: app),
            };
            return CallbackShortcuts(
              bindings: {
                const SingleActivator(
                  LogicalKeyboardKey.keyN,
                  control: true,
                ): () =>
                    editTask(context, app),
              },
              child: Scaffold(
                appBar: AppBar(
                  title: Text('LifeOS · ${labels[page]}'),
                  actions: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(child: Text('Local only')),
                    ),
                  ],
                ),
                drawer: wide
                    ? null
                    : NavigationDrawer(
                        selectedIndex: page,
                        onDestinationSelected: (index) {
                          Navigator.pop(context);
                          setState(() => page = index);
                        },
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('LifeOS · Your personal space'),
                          ),
                          ...List.generate(
                            labels.length,
                            (i) => NavigationDrawerDestination(
                              icon: Icon(icons[i]),
                              label: Flexible(
                                child: Tooltip(
                                  message: labels[i],
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                body: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide)
                        SizedBox(
                          width: 220,
                          child: NavigationDrawer(
                            selectedIndex: page,
                            onDestinationSelected: (index) =>
                                setState(() => page = index),
                            children: List.generate(
                              labels.length,
                              (i) => NavigationDrawerDestination(
                                icon: Icon(icons[i]),
                                label: Flexible(
                                  child: Tooltip(
                                    message: labels[i],
                                    child: Text(
                                      labels[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (wide) const VerticalDivider(width: 1),
                      Expanded(
                        child: Column(
                          children: [
                            if (app.busy) const LinearProgressIndicator(),
                            if (app.error != null)
                              MaterialBanner(
                                content: Text(app.error!),
                                actions: [
                                  TextButton(
                                    onPressed: app.dismissError,
                                    child: const Text('Dismiss'),
                                  ),
                                ],
                              ),
                            Expanded(
                              child: SingleChildScrollView(
                                key: ValueKey(page),
                                padding: EdgeInsets.all(wide ? 32 : 16),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1100,
                                    ),
                                    child: content,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
