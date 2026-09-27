import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/period.dart';
import '../providers/cycle_provider.dart';
import '../providers/log_provider.dart';
import '../services/cycle_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import 'mood_selector.dart';
import 'symptom_selector.dart';

/// Opens the "Log today" check-in sheet for [date] (defaults to today).
/// Used by Today ("Log today", "Edit") and Calendar ("Edit check-in").
Future<void> showLogTodaySheet(BuildContext context, {DateTime? date}) async {
  final day = dayKey(date ?? DateTime.now());
  final messenger = ScaffoldMessenger.maybeOf(context);
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => _LogTodaySheet(date: day),
  );
  if (saved == true && messenger != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: _LoggedToast(date: day),
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2500),
      ));
  }
}

class _LogTodaySheet extends StatefulWidget {
  const _LogTodaySheet({required this.date});

  final DateTime date;

  @override
  State<_LogTodaySheet> createState() => _LogTodaySheetState();
}

class _LogTodaySheetState extends State<_LogTodaySheet> {
  late final CycleProvider _cycle = context.read<CycleProvider>();
  late final LogProvider _logs = context.read<LogProvider>();
  late final TextEditingController _note;

  late String _flow;
  late List<String> _symptoms;
  String? _mood;

  Period? _period; // period covering the date when the sheet opened
  late bool _wasStarted, _wasEnded;
  late bool _started, _ended;
  bool _autoStarted = false;
  bool _saving = false;

  bool get _isToday => isSameDay(widget.date, today());

  @override
  void initState() {
    super.initState();
    final log = _logs.logFor(widget.date);
    _flow = log?.flow ?? 'none';
    _symptoms = [...?log?.symptoms];
    _mood = log?.mood;
    _note = TextEditingController(text: log?.note ?? '');

    _period = _cycle.periodOn(widget.date);
    final end = _period?.endDate;
    _started = _wasStarted = _period != null && isSameDay(_period!.startDate, widget.date);
    _ended = _wasEnded = end != null && isSameDay(end, widget.date);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// True when [widget.date] is already inside a logged or ongoing period.
  bool get _inPeriod =>
      _period != null ||
      _cycle.periods.any((p) => p.endDate == null && !p.startDate.isAfter(widget.date));

  void _setFlow(String id) {
    setState(() {
      _flow = id;
      if (id != 'none' && !_inPeriod && !_started) {
        _started = _autoStarted = true;
      } else if (id == 'none' && _autoStarted) {
        _started = _autoStarted = false;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final d = widget.date;
    final flow = _flow;

    await _logs.saveLog(
      date: d,
      flow: flow,
      symptoms: _symptoms,
      mood: _mood,
      note: _note.text,
    );

    final p = _period;
    if (p != null && _wasStarted && !_started) {
      await _cycle.deletePeriod(p.id);
    } else if (p != null && _wasEnded && !_ended) {
      final isLatest = _cycle.periods.every((o) => !o.startDate.isAfter(p.startDate));
      if (isLatest) await _cycle.savePeriod(p..endDate = null);
    }
    if (_started && !_wasStarted) {
      await _cycle.startPeriod(d, flow: flow == 'none' ? 'medium' : flow);
      await _cycle.load();
    }
    if (_ended && !_wasEnded) await _cycle.endPeriod(d);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = _cycle.dayInfo(widget.date);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    const pad = EdgeInsets.symmetric(horizontal: AppSpacing.margin);

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Column(
        children: [
          Padding(padding: pad, child: _Header(onClose: () => Navigator.pop(context))),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: pad, child: _title(c, info?.day)),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(padding: pad, child: _flowSection(c, info)),
                  const _Hairline(),
                  Padding(
                    padding: pad,
                    child: SymptomSelector(
                      selected: _symptoms,
                      onChanged: (v) => setState(() => _symptoms = v),
                    ),
                  ),
                  const _Hairline(),
                  Padding(
                    padding: pad,
                    child: _SectionHeader(
                      title: 'Mood',
                      trailing: Text(
                        'Present state',
                        style: AppText.labelSm.copyWith(color: c.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  MoodSelector(
                    selected: _mood,
                    onChanged: (v) => setState(() => _mood = v),
                  ),
                  const _Hairline(),
                  Padding(padding: pad, child: _noteSection(c)),
                  const SizedBox(height: AppSpacing.lg + AppSpacing.sm),
                  Padding(padding: pad, child: _footer(c)),
                ],
              ),
            ),
          ),
          SizedBox(height: insets),
        ],
      ),
    );
  }

  Widget _title(AppColors c, int? cycleDay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isToday ? 'How are you feeling today?' : 'How were you feeling?',
          style: AppText.headlineLgMobile.copyWith(color: c.primary, letterSpacing: -0.025 * 32),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: Text(
                formatLong(widget.date),
                style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant),
              ),
            ),
            if (cycleDay != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: c.outlineVariant, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                'Cycle Day $cycleDay',
                style: AppText.bodyMd.weight(500).copyWith(color: c.secondary),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _flowSection(AppColors c, ({int day, CyclePhase phase})? info) {
    final when = _isToday ? 'today' : formatShort(widget.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'FLOW INTENSITY',
                style: AppText.labelMd.copyWith(color: c.secondary, letterSpacing: 0.05 * 12),
              ),
            ),
            if (info != null)
              Text(
                'Day ${info.day} · ${info.phase.label}',
                style: AppText.bodySm.copyWith(
                  color: c.onSurfaceVariant.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _FlowSelector(selected: _flow, onChanged: _setFlow),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RadioToggle(
                label: 'Period started $when',
                value: _started,
                onChanged: (v) => setState(() {
                  _started = v;
                  _autoStarted = false;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RadioToggle(
                label: 'Period ended $when',
                value: _ended,
                onChanged: (v) => setState(() => _ended = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _noteSection(AppColors c) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      borderSide: BorderSide(color: c.outlineVariant.withValues(alpha: 0.4)),
    );
    final style = AppText.headlineSm.copyWith(fontStyle: FontStyle.italic, height: 1.625);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Anything worth remembering?',
          trailing: Icon(Symbols.edit_note, size: 18, weight: 300, color: c.outline),
        ),
        const SizedBox(height: AppSpacing.xs + 8),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: c.secondary,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          style: style.copyWith(color: c.onSurface),
          decoration: InputDecoration(
            hintText: 'A gentle walk this morning, felt grounded...',
            hintStyle: style.copyWith(color: c.outline.withValues(alpha: 0.7)),
            hintMaxLines: 3,
            filled: true,
            fillColor: c.surfaceContainerLow.withValues(alpha: 0.7),
            contentPadding: const EdgeInsets.all(14),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: c.secondary)),
          ),
        ),
      ],
    );
  }

  Widget _footer(AppColors c) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Material(
            color: c.primaryContainer,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _saving ? null : _save,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Save check-in', style: AppText.labelLg.copyWith(color: c.onPrimary)),
                  const SizedBox(width: 8),
                  Icon(Symbols.arrow_forward, size: 18, weight: 300, color: c.onPrimary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Opacity(
          opacity: 0.9,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.lock, size: 14, weight: 300, color: c.outline),
              const SizedBox(width: 6),
              Text(
                'Private · Encrypted locally on your device',
                style: AppText.bodySm.copyWith(color: c.outline),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Drag handle + "JOURNAL ENTRY" label + close button.
class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.outlineVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'JOURNAL ENTRY',
                  style: AppText.labelMd.copyWith(color: c.secondary, letterSpacing: 0.1 * 12),
                ),
              ),
              SizedBox.square(
                dimension: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: Icon(Symbols.close, size: 20, weight: 300, color: c.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.headlineSm.weight(400).copyWith(color: context.colors.primary),
          ),
        ),
        trailing,
      ],
    );
  }
}

/// `hairline-b pb-space-lg mb-space-lg` section divider.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        AppSpacing.lg,
        AppSpacing.margin,
        AppSpacing.lg,
      ),
      child: Container(height: 1, color: context.colors.outlineVariant.withValues(alpha: 0.4)),
    );
  }
}

/// Five-way segmented pill for [flowOptions].
class _FlowSelector extends StatelessWidget {
  const _FlowSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          for (final o in flowOptions) ...[
            if (o != flowOptions.first) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                selected: o.id == selected,
                child: GestureDetector(
                  onTap: () => onChanged(o.id),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o.id == selected ? c.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        o.label,
                        style: o.id == selected
                            ? AppText.labelSm.weight(600).copyWith(color: c.onPrimary)
                            : AppText.labelSm.copyWith(color: c.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small circular radio + label ("Period started today").
class _RadioToggle extends StatelessWidget {
  const _RadioToggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      checked: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: value ? c.primaryContainer : c.outlineVariant),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? c.primaryContainer : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppText.bodySm.copyWith(
                    color: value ? c.onSurface : c.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "check_circle Logged for Sep 23" floating confirmation pill.
class _LoggedToast extends StatelessWidget {
  const _LoggedToast({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: c.surfaceContainerHighest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.check_circle, size: 16, weight: 300, color: c.secondary),
                const SizedBox(width: 8),
                Text(
                  'Logged for ${formatShort(date)}',
                  style: AppText.labelSm.copyWith(color: c.onSurface, letterSpacing: 0.025 * 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
