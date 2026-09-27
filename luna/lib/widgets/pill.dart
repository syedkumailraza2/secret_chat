import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

/// Rounded chip from the Log Today symptom list.
/// Selected: filled `primaryContainer` with a check icon.
/// Unselected: `surfaceContainerHigh/60` with a hairline border.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onPrimary : c.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? c.primaryContainer
                : c.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : c.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Symbols.check, size: 15, weight: 300, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label, style: AppText.labelMd.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed-outline pill used for secondary "add" actions ("+ Add other").
class DashedPill extends StatelessWidget {
  const DashedPill({
    super.key,
    required this.label,
    this.icon = Symbols.add,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: _DashedStadiumPainter(c.outlineVariant),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, weight: 300, color: c.secondary),
                const SizedBox(width: 4),
                Text(label, style: AppText.labelMd.copyWith(color: c.secondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedStadiumPainter extends CustomPainter {
  _DashedStadiumPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 3.0, gap = 3.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadiumPainter old) => old.color != color;
}
