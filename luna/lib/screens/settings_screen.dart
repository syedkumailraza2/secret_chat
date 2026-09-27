import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../database/isar_service.dart';
import '../providers/cycle_provider.dart';
import '../providers/log_provider.dart';
import '../providers/settings_provider.dart';
import '../services/biometric_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../utils/helpers.dart';
import '../widgets/secret_trigger.dart';

/// Settings tab (luna-UI/settings.html).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<SettingsProvider>();
    final pad = MediaQuery.paddingOf(context);
    final t = s.reminderTime;
    final timeText = formatTime(DateTime(2000, 1, 1, t.hour, t.minute));

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.margin,
            pad.top + 80,
            AppSpacing.margin,
            pad.bottom + 110,
          ),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: AppText.headlineLgMobile.copyWith(color: c.primary)),
                  const SizedBox(height: 4),
                  Text('Preferences and on-device privacy',
                      style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),

            _Section(
              label: 'CYCLE PARAMETERS',
              top: AppSpacing.md,
              children: [
                _Row(
                  title: 'Cycle length',
                  value: pluralDays(s.cycleLength),
                  onTap: () => _editLength(context, cycle: true),
                ),
                _Row(
                  title: 'Period length',
                  value: pluralDays(s.periodLength),
                  onTap: () => _editLength(context, cycle: false),
                ),
              ],
            ),

            _Section(
              label: 'REMINDERS',
              children: [
                _Row(
                  title: 'Period reminder',
                  subtitle: 'Notify ~2 days before estimated period',
                  trailing: Switch(
                    value: s.periodReminderEnabled,
                    onChanged: (v) => _setReminder(context, v, s.setPeriodReminder),
                  ),
                ),
                _Row(
                  title: 'Daily check-in',
                  subtitle: t.hour >= 17
                      ? 'Gentle evening reminder at $timeText'
                      : 'Gentle reminder at $timeText',
                  onTap: () => _pickTime(context),
                  trailing: Switch(
                    value: s.dailyReminderEnabled,
                    onChanged: (v) => _setReminder(context, v, s.setDailyReminder),
                  ),
                ),
              ],
            ),

            _Section(
              label: 'PRIVACY & DATA',
              footer: Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Symbols.shield_lock, size: 16, weight: 300, color: c.onSurfaceVariant),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'All cycle data is encrypted and stored 100% on your device. '
                        'Luna will never sell, transfer, or upload your bodily health records.',
                        style: AppText.bodySm.copyWith(color: c.onSurfaceVariant, height: 1.625),
                      ),
                    ),
                  ],
                ),
              ),
              children: [
                _Row(
                  title: 'App lock',
                  subtitle: 'Require Face ID / Touch ID',
                  trailing: Switch(
                    value: s.biometricLockEnabled,
                    onChanged: (v) => _setAppLock(context, v),
                  ),
                ),
                _Row(
                  title: 'Export data',
                  subtitle: 'Download raw logs in JSON or CSV',
                  onTap: () => _export(context),
                ),
                _Row(
                  title: 'Delete all data',
                  subtitle: 'Permanently erase on-device cycle records',
                  danger: true,
                  onTap: () => _deleteAll(context),
                ),
              ],
            ),

            _Section(
              label: 'APPEARANCE',
              divided: false,
              children: [
                const SizedBox(height: AppSpacing.sm),
                _ThemeSegments(value: s.themeMode, onChanged: s.setThemeMode),
              ],
            ),

            // About & disclosures
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xl),
              child: Column(
                children: [
                  _LinkRow(label: 'Privacy Policy', onTap: () => _openDoc(context, _privacyDoc)),
                  const Divider(),
                  _LinkRow(label: 'Medical Disclaimer', onTap: () => _openDoc(context, _medicalDoc)),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('About Luna v$appVersion',
                              style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant)),
                        ),
                        Text('Offline · On-device', style: AppText.labelSm.copyWith(color: c.outline)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                    child: Text(
                      'Crafted with quiet reverence for the bodily rhythm.',
                      textAlign: TextAlign.center,
                      style: AppText.headlineSm.copyWith(color: c.outline, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Positioned(top: 0, left: 0, right: 0, child: _TopBar()),
      ],
    );
  }

  // ---- Actions ------------------------------------------------------------

  static void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _setReminder(BuildContext context, bool on, Future<void> Function(bool) set) async {
    if (on && !await NotificationService.instance.requestPermission()) {
      if (context.mounted) _snack(context, 'Notifications are turned off for Luna in system settings.');
      return;
    }
    await set(on);
  }

  Future<void> _setAppLock(BuildContext context, bool on) async {
    final settings = context.read<SettingsProvider>();
    if (on) {
      if (!await BiometricService.instance.isAvailable()) {
        if (context.mounted) _snack(context, 'Face ID / Touch ID is not set up on this device.');
        return;
      }
      if (!await BiometricService.instance.authenticate(reason: 'Confirm to turn on App lock')) return;
    }
    await settings.setBiometricLock(on);
  }

  Future<void> _pickTime(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final c = context.colors;
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
      helpText: 'DAILY CHECK-IN',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            helpTextStyle: AppText.labelSm.copyWith(color: c.outline),
            dialBackgroundColor: c.surfaceContainerHigh,
            dialHandColor: c.primaryContainer,
            dialTextColor: WidgetStateColor.resolveWith(
              (st) => st.contains(WidgetState.selected) ? c.surface : c.onSurface,
            ),
            hourMinuteColor: WidgetStateColor.resolveWith(
              (st) => st.contains(WidgetState.selected) ? c.secondaryContainer : c.surfaceContainerHigh,
            ),
            hourMinuteTextColor: WidgetStateColor.resolveWith(
              (st) => st.contains(WidgetState.selected) ? c.onSecondaryContainer : c.onSurface,
            ),
            dayPeriodColor: c.secondaryContainer,
            dayPeriodTextColor: c.onSurface,
            dayPeriodBorderSide: BorderSide(color: c.outlineVariant),
            entryModeIconColor: c.onSurfaceVariant,
            cancelButtonStyle: TextButton.styleFrom(foregroundColor: c.onSurfaceVariant, textStyle: AppText.labelLg),
            confirmButtonStyle: TextButton.styleFrom(foregroundColor: c.primary, textStyle: AppText.labelLg),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) await settings.setReminderTime(picked);
  }

  void _editLength(BuildContext context, {required bool cycle}) {
    final settings = context.read<SettingsProvider>();
    _showSheet(
      context,
      _LengthSheet(
        title: cycle ? 'Cycle length' : 'Period duration',
        caption: cycle ? 'ESTIMATED INTERVAL' : 'BLEED PHASE',
        note: cycle ? 'Typical range is 24–35 days.' : 'Typical range is 3–7 days.',
        initial: cycle ? settings.cycleLength : settings.periodLength,
        min: cycle ? minCycleLength : minPeriodLength,
        max: cycle ? maxCycleLength : maxPeriodLength,
        onSave: cycle ? settings.setCycleLength : settings.setPeriodLength,
      ),
    );
  }

  void _export(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    _showSheet(
      context,
      _ExportSheet(
        onPick: (format) async {
          try {
            await ExportService.instance.exportAndShare(format, origin: origin);
          } catch (_) {
            if (context.mounted) _snack(context, 'Export failed. Please try again.');
          }
        },
      ),
    );
  }

  Future<void> _deleteAll(BuildContext context) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Delete all data?', style: AppText.headlineSm.copyWith(color: c.onSurface)),
        content: Text(
          'This permanently erases every period, check-in, and setting stored on this device. '
          'It cannot be undone.',
          style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppText.labelLg.copyWith(color: c.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: AppText.labelLg.copyWith(color: c.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final settings = context.read<SettingsProvider>();
    final cycle = context.read<CycleProvider>();
    final logs = context.read<LogProvider>();
    await IsarService.instance.clearAll();
    await NotificationService.instance.cancelAll();
    await Future.wait([cycle.load(), logs.load()]);
    await settings.reset(); // returns the app to onboarding
  }

  void _openDoc(BuildContext context, _Doc doc) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _DocPage(doc: doc)),
      );

  static Future<void> _showSheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        builder: (_) => child,
      );
}

// ---- Layout pieces ---------------------------------------------------------

/// Fixed, blurred top app bar from the shared design component.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: c.surface.withValues(alpha: 0.9),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.margin,
            MediaQuery.paddingOf(context).top + AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon and wordmark sit apart in this spaceBetween row, so each
              // carries its own trigger to keep the layout unchanged.
              SecretTrigger(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Symbols.spa, weight: 300, color: c.primary),
                ),
              ),
              SecretTrigger(
                child: Text('Luna', style: AppText.headlineMd.copyWith(color: c.primary)),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Symbols.account_circle, weight: 300, color: c.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.children,
    this.top = AppSpacing.sm,
    this.divided = true,
    this.footer,
  });

  final String label;
  final List<Widget> children;
  final double top;
  final bool divided;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(label, style: AppText.labelSm.weight(600).copyWith(color: c.outline)),
          ),
          if (divided)
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(),
              children[i],
            ]
          else
            ...children,
          ?footer,
        ],
      ),
    );
  }
}

/// A settings row: serif title, optional subtitle, and a value/chevron or a switch.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chevron = Icon(
      Symbols.chevron_right,
      weight: 300,
      color: danger && dark ? c.error : c.outlineVariant,
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.headlineSm.copyWith(color: danger ? c.error : c.onSurface)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle!, style: AppText.bodySm.copyWith(color: c.onSurfaceVariant)),
          ),
      ],
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: text),
          const SizedBox(width: 16),
          if (trailing != null)
            trailing!
          else ...[
            if (value != null) ...[
              Text(value!, style: AppText.bodyMd.weight(500).copyWith(color: c.primary)),
              const SizedBox(width: 8),
            ],
            chevron,
          ],
        ],
      ),
    );
    // A switch in [trailing] still wins its own taps; the rest of the row opens [onTap].
    return onTap == null ? row : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant))),
            Icon(Symbols.north_east, size: 14, weight: 300, color: c.outlineVariant),
          ],
        ),
      ),
    );
  }
}

/// Light / Dark / System pill control.
class _ThemeSegments extends StatelessWidget {
  const _ThemeSegments({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Dark design uses a softer rose selection; light uses the deep wine pill.
    final selectedBg = dark ? c.secondaryContainer : c.primary;
    final selectedFg = dark ? c.primaryFixed : c.onPrimary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? c.surfaceContainerLow : c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: c.outlineVariant.withValues(alpha: dark ? 0.3 : 0.2)),
      ),
      child: Row(
        children: [
          for (final (mode, label) in const [
            (ThemeMode.light, 'Light'),
            (ThemeMode.dark, 'Dark'),
            (ThemeMode.system, 'System'),
          ])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: mode == value ? selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: mode == value
                        ? [BoxShadow(color: c.onSurface.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.labelMd.copyWith(color: mode == value ? selectedFg : c.onSurfaceVariant),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Sheets ----------------------------------------------------------------

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.margin, AppSpacing.sm, AppSpacing.margin, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Stepper sheet styled after onboarding3.html's parameter adjusters.
class _LengthSheet extends StatefulWidget {
  const _LengthSheet({
    required this.title,
    required this.caption,
    required this.note,
    required this.initial,
    required this.min,
    required this.max,
    required this.onSave,
  });

  final String title;
  final String caption;
  final String note;
  final int initial;
  final int min;
  final int max;
  final Future<void> Function(int) onSave;

  @override
  State<_LengthSheet> createState() => _LengthSheetState();
}

class _LengthSheetState extends State<_LengthSheet> {
  late int _value = widget.initial.clamp(widget.min, widget.max);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _SheetFrame(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(widget.title, style: AppText.headlineSm.weight(400).copyWith(color: c.onSurface))),
            Text(widget.caption, style: AppText.labelSm.copyWith(color: c.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$_value', style: AppText.displayHeroMobile.copyWith(color: c.primary)),
                  const SizedBox(width: 8),
                  Text('days',
                      style: AppText.headlineSm.weight(400).copyWith(
                            color: c.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          )),
                ],
              ),
            ),
            _StepButton(
              icon: Symbols.remove,
              label: 'Decrease',
              onTap: _value > widget.min ? () => setState(() => _value--) : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StepButton(
              icon: Symbols.add,
              label: 'Increase',
              onTap: _value < widget.max ? () => setState(() => _value++) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(widget.note, style: AppText.bodySm.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.8))),
        const SizedBox(height: AppSpacing.lg),
        _PrimaryButton(
          label: 'Save',
          onTap: () async {
            await widget.onSave(_value);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface.withValues(alpha: 0.5),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, size: 18, weight: 300, color: c.onSurface),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(label, style: AppText.labelLg.copyWith(color: c.surface)),
      ),
    );
  }
}

class _ExportSheet extends StatelessWidget {
  const _ExportSheet({required this.onPick});

  final Future<void> Function(ExportFormat) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget option(ExportFormat f, String title, String subtitle) => _Row(
          title: title,
          subtitle: subtitle,
          onTap: () {
            Navigator.pop(context);
            onPick(f);
          },
        );

    return _SheetFrame(
      children: [
        Text('Export data', style: AppText.headlineSm.copyWith(color: c.onSurface)),
        const SizedBox(height: 4),
        Text(
          'A copy of your records is prepared on this device and handed to the share sheet. '
          'You choose where it goes.',
          style: AppText.bodySm.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        option(ExportFormat.json, 'JSON', 'Complete structured export: settings, periods, check-ins'),
        const Divider(),
        option(ExportFormat.csv, 'CSV', 'One row per day, ready for any spreadsheet'),
      ],
    );
  }
}

// ---- Disclosure pages ------------------------------------------------------

typedef _Doc = ({String title, List<String> paragraphs});

const _Doc _privacyDoc = (
  title: 'Privacy Policy',
  paragraphs: [
    'Luna has no accounts, no servers, no ads, and no analytics. The app makes no network requests.',
    'Your periods, daily check-ins, and settings are kept only in a local database on this device, '
        'protected by your device\'s built-in storage encryption and passcode.',
    'Reminders are scheduled locally by your phone\'s operating system. Nothing is sent anywhere to deliver them.',
    'Your data leaves the device only when you choose Export data and share the file yourself. '
        'Once shared, that copy is governed by wherever you send it.',
    'Delete all data permanently erases everything Luna has stored. Uninstalling the app does the same.',
  ],
);

const _Doc _medicalDoc = (
  title: 'Medical Disclaimer',
  paragraphs: [
    'Luna is a personal journal, not a medical device.',
    'Predicted periods, fertile windows, and ovulation days are estimates calculated from the dates you log. '
        'They can be wrong, especially when cycles are irregular or recently changed.',
    'Do not rely on Luna for contraception or to plan or prevent a pregnancy. '
        'Luna does not diagnose, treat, or prevent any condition.',
    'If you have concerns about your cycle, pain, or bleeding, or if something feels different, '
        'please talk to a qualified healthcare professional.',
  ],
);

class _DocPage extends StatelessWidget {
  const _DocPage({required this.doc});

  final _Doc doc;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Symbols.arrow_back, weight: 300, color: c.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.margin, AppSpacing.sm, AppSpacing.margin, AppSpacing.xl),
        children: [
          Text(doc.title, style: AppText.headlineLgMobile.copyWith(color: c.primary)),
          const SizedBox(height: AppSpacing.lg),
          for (final p in doc.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(p, style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
