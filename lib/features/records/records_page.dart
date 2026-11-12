import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../core/app_controller.dart';
import '../../domain/records.dart';
import '../../domain/models.dart';
import '../../ui/common.dart';
import '../../ui/entry_editor.dart';

class RecordsPanel extends StatefulWidget {
  const RecordsPanel({
    super.key,
    required this.app,
    required this.kind,
    this.category,
  });
  final AppController app;
  final EntryKind kind;
  final Category? category;
  @override
  State<RecordsPanel> createState() => _RecordsPanelState();
}

class _RecordsPanelState extends State<RecordsPanel> {
  int count = 25;
  @override
  Widget build(BuildContext context) {
    final entries =
        widget.app.entries
            .where(
              (e) =>
                  e.kind == widget.kind &&
                  (widget.category == null || e.category == widget.category),
            )
            .toList()
          ..sort((a, b) => b.day.compareTo(a.day));
    return Section(
      title: '${entryLabels[widget.kind]}s',
      action: OutlinedButton.icon(
        onPressed: widget.app.busy
            ? null
            : () => editEntry(
                context,
                widget.app,
                widget.kind,
                category: widget.category,
              ),
        icon: const Icon(Icons.add),
        label: Text('Add ${entryLabels[widget.kind]!.toLowerCase()}'),
      ),
      child: entries.isEmpty
          ? const EmptyMessage('No entries yet.')
          : Column(
              children: [
                ...entries
                    .take(count)
                    .map(
                      (entry) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        Text(
                                          '${entry.day} · ${entry.category.label}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    enabled: !widget.app.busy,
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                    onSelected: (action) async {
                                      if (action == 'edit')
                                        await editEntry(
                                          context,
                                          widget.app,
                                          widget.kind,
                                          entry: entry,
                                        );
                                      if (action == 'delete' &&
                                          await confirmDelete(
                                            context,
                                            entry.title,
                                          ))
                                        await widget.app.run(
                                          () => widget.app.repository
                                              .deleteEntry(entry.id),
                                        );
                                    },
                                  ),
                                ],
                              ),
                              if (entry.kind == EntryKind.goal) ...[
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: entry.number('target') <= 0
                                      ? 0
                                      : (entry.number('current') /
                                                entry.number('target'))
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                ),
                                Text(
                                  '${entry.text('current').isEmpty ? '0' : entry.text('current')} / ${entry.text('target')} ${entry.text('unit')}',
                                ),
                                if (widget.app.tasks.any(
                                  (t) => t.goalId == entry.id,
                                ))
                                  Text(
                                    '${widget.app.tasks.where((t) => t.goalId == entry.id && t.done).length} linked tasks completed',
                                  ),
                              ],
                              if (entry.kind == EntryKind.photo)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Image.memory(
                                    base64Decode(entry.text('image')),
                                    width: 240,
                                    height: 240,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, error, stack) =>
                                        const Text(
                                          'Photo could not be decoded.',
                                        ),
                                  ),
                                ),
                              ...entryFields[entry.kind]!
                                  .where(
                                    (f) =>
                                        f.key != 'milestones' &&
                                        entry.text(f.key).isNotEmpty,
                                  )
                                  .map(
                                    (field) => Text(
                                      '${field.label}: ${entry.text(field.key)}',
                                    ),
                                  ),
                              if (entry.text('milestones').isNotEmpty)
                                ...entry
                                    .text('milestones')
                                    .split('\n')
                                    .asMap()
                                    .entries
                                    .map(
                                      (line) => CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          line.value.replaceFirst(
                                            RegExp(r'^✓ '),
                                            '',
                                          ),
                                        ),
                                        value: line.value.startsWith('✓ '),
                                        onChanged: widget.app.busy
                                            ? null
                                            : (checked) async {
                                                final lines = entry
                                                    .text('milestones')
                                                    .split('\n');
                                                lines[line.key] =
                                                    '${checked == true ? '✓ ' : ''}${line.value.replaceFirst(RegExp(r'^✓ '), '')}';
                                                final value = entry.toJson()
                                                  ..['values'] = {
                                                    ...entry.values,
                                                    'milestones': lines.join(
                                                      '\n',
                                                    ),
                                                  }
                                                  ..['updatedAt'] =
                                                      DateTime.now()
                                                          .toUtc()
                                                          .toIso8601String();
                                                await widget.app.run(
                                                  () => widget.app.repository
                                                      .saveEntry(
                                                        LocalEntry.fromJson(
                                                          value,
                                                        ),
                                                      ),
                                                );
                                              },
                                      ),
                                    ),
                              if (entry.revisions.isNotEmpty)
                                ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text('Target history'),
                                  children: entry.revisions
                                      .map(
                                        (r) => ListTile(
                                          title: Text(
                                            '${r['target']} ${r['unit']}',
                                          ),
                                          subtitle: Text(
                                            widget.app.clock.localStamp(
                                              r['at']!,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              if (entry.notes.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(entry.notes),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                if (entries.length > count)
                  TextButton(
                    onPressed: () => setState(() => count += 25),
                    child: Text(
                      'Show more (${entries.length - count} remaining)',
                    ),
                  ),
              ],
            ),
    );
  }
}
