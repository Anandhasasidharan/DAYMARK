import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/models.dart';
import '../../ui/common.dart';

class StudyTimer extends StatefulWidget {
  const StudyTimer({super.key, required this.app});
  final AppController app;
  @override
  State<StudyTimer> createState() => _StudyTimerState();
}

class _StudyTimerState extends State<StudyTimer> {
  final topic = TextEditingController();
  Timer? ticker;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watch = widget.app.studyStopwatch;
    final minutes = watch.elapsed.inMinutes;
    final seconds = watch.elapsed.inSeconds % 60;
    return Section(
      title: 'Study timer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const Text(
            'Saves whole completed minutes to today. You can change pages while timing. Closing the app discards an unsaved timer.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: topic,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Topic / subject'),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => setState(
                  () => watch.isRunning ? watch.stop() : watch.start(),
                ),
                child: Text(watch.isRunning ? 'Pause' : 'Start'),
              ),
              OutlinedButton(
                onPressed: minutes < 1 || widget.app.busy
                    ? null
                    : () async {
                        if (topic.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a topic first.'),
                            ),
                          );
                          return;
                        }
                        watch.stop();
                        final now = DateTime.now().toUtc().toIso8601String();
                        final ok = await widget.app.run(
                          () => widget.app.repository.saveActivity(
                            ActivityRecord(
                              id: newId(),
                              category: Category.learning,
                              title: topic.text.trim(),
                              day: widget.app.clock.today,
                              minutes: minutes,
                              createdAt: now,
                              updatedAt: now,
                              notes: 'Recorded with study timer.',
                            ),
                          ),
                        );
                        if (ok && mounted) setState(() => watch.reset());
                      },
                child: const Text('Save session'),
              ),
              TextButton(
                onPressed: () async {
                  final discard = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Discard unsaved timer?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Discard'),
                        ),
                      ],
                    ),
                  );
                  if (discard == true && mounted)
                    setState(() {
                      watch.stop();
                      watch.reset();
                    });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
