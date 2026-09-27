import 'package:flutter/material.dart';

import '../services/insights_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// "Your cycles" timeline: one hairline bar per cycle, width proportional to
/// its length, with the period portion drawn in the darker tone.
class CycleBars extends StatelessWidget {
  const CycleBars({super.key, required this.bars, this.muted = false});

  final List<CycleBar> bars;

  /// Baseline-only preview (no tracked cycles yet).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxLen = bars.fold<int>(0, (m, b) => b.length > m ? b.length : m);
    return Opacity(
      opacity: muted ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            for (var i = 0; i < bars.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _row(c, bars[i], maxLen),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(AppColors c, CycleBar bar, int maxLen) {
    // Longest cycle fills ~94% of the track, as in the design.
    final widthFactor = (bar.length / (maxLen * 1.06)).clamp(0.05, 1.0);
    final periodFactor = (bar.periodLength / bar.length).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text('${bar.length}d',
              style: AppText.bodySm.weight(500).copyWith(color: c.onSurfaceVariant)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      _pill(c.secondaryFixed, double.infinity),
                      FractionallySizedBox(
                        widthFactor: periodFactor,
                        child: _pill(c.primaryContainer, double.infinity),
                      ),
                      // End dot: w-2 h-2 bg-primary ring-2 ring-background.
                      Positioned(
                        right: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(bar.label, style: AppText.labelSm.copyWith(color: c.secondary)),
      ],
    );
  }

  Widget _pill(Color color, double width) => Container(
        width: width,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      );
}

/// Legend under the bars: "Period flow" / "Follicular & Luteal".
class CycleBarsLegend extends StatelessWidget {
  const CycleBarsLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(text, style: AppText.labelSm.copyWith(color: c.onSurfaceVariant)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm + AppSpacing.xs),
      child: Row(
        children: [
          item(c.primaryContainer, 'Period flow'),
          const SizedBox(width: AppSpacing.md),
          item(c.secondaryFixed, 'Follicular & Luteal'),
        ],
      ),
    );
  }
}
