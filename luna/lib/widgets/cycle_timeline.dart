import 'package:flutter/material.dart';

import '../services/cycle_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

extension PhaseAccent on AppColors {
  Color accentFor(CyclePhase p) => switch (p) {
        CyclePhase.menstrual => menstrual,
        CyclePhase.follicular => follicular,
        CyclePhase.ovulation => ovulation,
        CyclePhase.luteal => luteal,
      };
}

/// Proportional 2px phase bar with a pulsing "YOU ARE HERE" marker and the
/// phase labels + day ranges beneath. Pass a null [progress] to hide the
/// marker (no history yet).
class CycleTimeline extends StatelessWidget {
  const CycleTimeline({super.key, required this.phases, this.current, this.progress});

  final List<PhaseRange> phases;
  final CyclePhase? current;
  final double? progress;

  static const _barTop = 32.0; // pt-6 + mt-2

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final markerLabel = AppText.labelSm.copyWith(
      color: c.primary,
      fontSize: 10,
      letterSpacing: 1,
    ).weight(600);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _barTop + 2,
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              final p = progress;
              final x = p == null ? 0.0 : p * w;
              final tp = TextPainter(
                text: TextSpan(text: 'YOU ARE HERE', style: markerLabel),
                textDirection: TextDirection.ltr,
                maxLines: 1,
              )..layout();
              final lw = tp.width;
              tp.dispose();
              final labelLeft = (x - lw / 2).clamp(0.0, (w - lw).clamp(0.0, w));

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _barTop,
                    height: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: ColoredBox(
                        color: c.outlineVariant.withValues(alpha: 0.4),
                        child: Row(
                          // Childless ColoredBoxes collapse to zero height
                          // unless the row stretches them to the 2px bar.
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final r in phases)
                              Expanded(flex: r.length, child: ColoredBox(color: c.accentFor(r.phase))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (p != null) ...[
                    Positioned(
                      top: -4,
                      left: labelLeft,
                      child: Text('YOU ARE HERE', style: markerLabel, maxLines: 1),
                    ),
                    // Dot centre: -4 (top) + 14 (label) + 4 (mb-1) + 5 (half dot).
                    Positioned(
                      top: 19 - 10,
                      left: x - 10,
                      width: 20,
                      height: 20,
                      child: const _PulsingDot(),
                    ),
                  ],
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < phases.length; i++)
                Expanded(
                  child: _PhaseLabel(
                    range: phases[i],
                    active: phases[i].phase == current,
                    align: i == 0
                        ? CrossAxisAlignment.start
                        : i == phases.length - 1
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.center,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({required this.range, required this.active, required this.align});

  final PhaseRange range;
  final bool active;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textAlign = switch (align) {
      CrossAxisAlignment.start => TextAlign.left,
      CrossAxisAlignment.end => TextAlign.right,
      _ => TextAlign.center,
    };
    final name = AppText.labelSm.copyWith(
      fontSize: 10,
      letterSpacing: 0.5,
      color: active ? c.primary : c.onSurfaceVariant,
    );
    final days = range.startDay == range.endDay
        ? 'Day ${range.startDay}'
        : 'Days ${range.startDay}–${range.endDay}';
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          range.phase.shortLabel.toUpperCase(),
          style: active ? name.weight(700) : name,
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
        ),
        const SizedBox(height: 2),
        Text(
          days,
          style: AppText.labelSm.copyWith(
            fontSize: 9,
            color: active ? c.onPrimaryContainer : c.outline,
          ),
          textAlign: textAlign,
        ),
      ],
    );
  }
}

/// 10px dot with a 20px ring pulsing scale 1→1.6, opacity .8→.15 over 3s.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));
  static const _curve = Cubic(0.4, 0, 0.6, 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = _ctrl.value;
            final k = t < 0.5 ? _curve.transform(t * 2) : 1 - _curve.transform(t * 2 - 1);
            return Opacity(
              opacity: 0.8 - 0.65 * k,
              child: Transform.scale(scale: 1 + 0.6 * k, child: child),
            );
          },
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: c.surface),
          ),
        ),
      ],
    );
  }
}
