import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../utils/constants.dart';
import 'pill.dart';

/// "Anything you're noticing?" block: header with SELECT ALL, a wrap of
/// multi-select [Pill]s for [symptomOptions] plus any custom symptoms, and a
/// dashed "Add other" chip. Custom symptoms are stored as their label.
class SymptomSelector extends StatefulWidget {
  const SymptomSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.title = "Anything you're noticing?",
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String title;

  @override
  State<SymptomSelector> createState() => _SymptomSelectorState();
}

class _SymptomSelectorState extends State<SymptomSelector> {
  /// Custom symptoms, kept visible after being deselected in this session.
  late final List<String> _custom = [
    for (final s in widget.selected)
      if (!symptomOptions.any((o) => o.id == s)) s,
  ];

  List<String> get _all => [...symptomOptions.map((o) => o.id), ..._custom];

  bool get _allSelected => _all.every(widget.selected.contains);

  void _toggle(String id) {
    final next = [...widget.selected];
    next.contains(id) ? next.remove(id) : next.add(id);
    widget.onChanged(next);
  }

  void _toggleAll() => widget.onChanged(_allSelected ? [] : _all);

  Future<void> _addOther() async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _AddSymptomDialog(),
    );
    final text = label?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    final existing = symptomOptions.where(
      (o) => o.label.toLowerCase() == text.toLowerCase(),
    );
    final id = existing.isNotEmpty ? existing.first.id : text;
    if (existing.isEmpty && !_custom.contains(id)) setState(() => _custom.add(id));
    if (!widget.selected.contains(id)) widget.onChanged([...widget.selected, id]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: AppText.headlineSm.weight(400).copyWith(color: c.primary),
              ),
            ),
            GestureDetector(
              onTap: _toggleAll,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _allSelected ? 'CLEAR ALL' : 'SELECT ALL',
                  style: AppText.labelSm.copyWith(color: c.outline, letterSpacing: 0.05 * 11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in symptomOptions)
              Pill(
                label: o.label,
                selected: widget.selected.contains(o.id),
                onTap: () => _toggle(o.id),
              ),
            for (final s in _custom)
              Pill(
                label: s,
                selected: widget.selected.contains(s),
                onTap: () => _toggle(s),
              ),
            DashedPill(label: 'Add other', onTap: _addOther),
          ],
        ),
      ],
    );
  }
}

class _AddSymptomDialog extends StatefulWidget {
  const _AddSymptomDialog();

  @override
  State<_AddSymptomDialog> createState() => _AddSymptomDialogState();
}

class _AddSymptomDialogState extends State<_AddSymptomDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text(
        'Add a symptom',
        style: AppText.headlineSm.weight(400).copyWith(color: c.primary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        cursorColor: c.secondary,
        style: AppText.bodyMd.copyWith(color: c.onSurface),
        decoration: InputDecoration(
          hintText: 'e.g. Tender breasts',
          hintStyle: AppText.bodyMd.copyWith(color: c.outline.withValues(alpha: 0.7)),
          counterText: '',
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.outlineVariant)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.secondary)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.labelLg.copyWith(color: c.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Add', style: AppText.labelLg.copyWith(color: c.primary)),
        ),
      ],
    );
  }
}
