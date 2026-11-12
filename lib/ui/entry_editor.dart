import 'package:material_ui/material_ui.dart';

import '../core/app_controller.dart';
import '../core/local_files.dart';
import '../core/clock.dart';
import '../domain/models.dart';
import '../domain/records.dart';

Future<void> editEntry(
  BuildContext context,
  AppController app,
  EntryKind kind, {
  LocalEntry? entry,
  Category? category,
}) async {
  final result = await showDialog<LocalEntry>(
    context: context,
    builder: (_) =>
        EntryEditor(app: app, kind: kind, entry: entry, category: category),
  );
  if (result != null) await app.run(() => app.repository.saveEntry(result));
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.app,
    required this.kind,
    this.entry,
    this.category,
  });
  final AppController app;
  final EntryKind kind;
  final LocalEntry? entry;
  final Category? category;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  late Category category;
  String? error, image;
  @override
  void initState() {
    super.initState();
    category = widget.entry?.category ?? widget.category ?? Category.learning;
    controllers['title'] = TextEditingController(
      text: widget.entry?.title ?? '',
    );
    final today = widget.app.clock.now;
    final defaultDay = widget.kind == EntryKind.review
        ? dateKey(
            DateTime(
              today.year,
              today.month,
              today.day -
                  (today.weekday -
                          widget.app.snapshot.preferences.weekStart +
                          7) %
                      7,
            ),
          )
        : widget.app.clock.today;
    controllers['day'] = TextEditingController(
      text: widget.entry?.day ?? defaultDay,
    );
    controllers['notes'] = TextEditingController(
      text: widget.entry?.notes ?? '',
    );
    for (final field in entryFields[widget.kind]!) {
      final fallback = field.kind == FieldKind.choice
          ? field.options.first
          : field.kind == FieldKind.weekdays
          ? '1,2,3,4,5,6,7'
          : '';
      final saved = widget.entry?.text(field.key) ?? '';
      controllers[field.key] = TextEditingController(
        text: saved.isEmpty ? fallback : saved,
      );
    }
    image = widget.entry?.text('image');
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget textField(
    String key,
    String label, {
    int lines = 1,
    bool numeric = false,
    int max = 200,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controllers[key],
      decoration: InputDecoration(
        labelText: label,
        helperText: key == 'milestones' ? 'One milestone per line' : null,
        border: const OutlineInputBorder(),
      ),
      maxLines: lines,
      maxLength: max,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
    ),
  );
  Widget field(EntryField field) {
    if (field.kind == FieldKind.choice)
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: controllers[field.key]!.text.isEmpty
              ? field.options.first
              : controllers[field.key]!.text,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          items: field.options
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) => controllers[field.key]!.text = value!,
        ),
      );
    if (field.kind == FieldKind.weekdays) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final selected = controllers[field.key]!.text.split(',').toSet();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          spacing: 4,
          children: List.generate(
            7,
            (i) => FilterChip(
              label: Text(names[i]),
              selected: selected.contains('${i + 1}'),
              onSelected: (checked) => setState(() {
                if (checked) {
                  selected.add('${i + 1}');
                } else {
                  selected.remove('${i + 1}');
                }
                controllers[field.key]!.text = (selected.toList()..sort()).join(
                  ',',
                );
              }),
            ),
          ),
        ),
      );
    }
    return textField(
      field.key,
      '${field.label}${field.kind == FieldKind.day ? ' (YYYY-MM-DD)' : ''}${field.required ? ' *' : ''}',
      lines: field.kind == FieldKind.notes ? 3 : 1,
      numeric: field.kind == FieldKind.number,
      max: field.kind == FieldKind.notes ? 10000 : 200,
    );
  }

  void save() {
    try {
      parseDay(controllers['day']!.text);
      if ([
            EntryKind.practice,
            EntryKind.measurement,
            EntryKind.photo,
          ].contains(widget.kind) &&
          controllers['day']!.text.compareTo(widget.app.clock.today) > 0)
        throw const FormatException(
          'Actual logs cannot be dated in the future.',
        );
      final now = DateTime.now().toUtc().toIso8601String();
      final values = {
        for (final f in entryFields[widget.kind]!)
          f.key: controllers[f.key]!.text.trim(),
      };
      if (widget.kind == EntryKind.photo) values['image'] = image ?? '';
      final entry = LocalEntry.fromJson(
        LocalEntry(
          id: widget.entry?.id ?? newId(),
          kind: widget.kind,
          title: controllers['title']!.text.trim(),
          category: category,
          day: controllers['day']!.text,
          notes: controllers['notes']!.text.trim(),
          values: values,
          createdAt: widget.entry?.createdAt ?? now,
          updatedAt: now,
        ).toJson(),
      );
      Navigator.pop(context, entry);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.entry == null ? 'New' : 'Edit'} ${entryLabels[widget.kind]!.toLowerCase()}',
    ),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              textField('title', 'Title *'),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<Category>(
                  isExpanded: true,
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: Category.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => category = value!),
                ),
              ),
              textField('day', switch (widget.kind) {
                EntryKind.habit => 'Start date (YYYY-MM-DD)',
                EntryKind.revision ||
                EntryKind.reminder => 'Due date (YYYY-MM-DD)',
                EntryKind.review => 'Week starting (YYYY-MM-DD)',
                _ => 'Date (YYYY-MM-DD)',
              }),
              ...entryFields[widget.kind]!.map(field),
              if (widget.kind == EntryKind.photo) ...[
                const Text(
                  'A thumbnail up to 320 × 320 is stored locally and included in JSON backups. The original stays where it is.',
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      final selected = await selectPhotoThumbnail();
                      if (selected != null && mounted)
                        setState(() {
                          image = selected;
                          error = null;
                        });
                    } catch (e) {
                      if (mounted) setState(() => error = e.toString());
                    }
                  },
                  child: Text(
                    image == null || image!.isEmpty
                        ? 'Choose photo'
                        : 'Replace photo',
                  ),
                ),
              ],
              textField('notes', 'Notes', lines: 3, max: 10000),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save')),
    ],
  );
}
