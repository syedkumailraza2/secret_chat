import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';

/// The circular bookmark button that floats over recipe imagery.
///
/// Outline when unsaved, filled and tinted primary when saved, with the little
/// scale pop the HTML does on toggle.
class FavoriteButton extends StatefulWidget {
  final bool isSaved;
  final VoidCallback onTap;
  final double size;

  const FavoriteButton({
    super.key,
    required this.isSaved,
    required this.onTap,
    this.size = 40,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    lowerBound: 1.0,
    upperBound: 1.2,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    widget.onTap();
    await _controller.forward();
    if (mounted) await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ScaleTransition(
              scale: _controller,
              child: Icon(
                Symbols.bookmark,
                size: widget.size * 0.5,
                fill: widget.isSaved ? 1 : 0,
                color: widget.isSaved
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
