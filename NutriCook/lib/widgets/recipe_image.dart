import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Turns whatever the API stored into something loadable.
///
/// Seeded recipes carry absolute `https://` URLs. Generated ones carry a
/// relative path like `/media/gen-abc123.png`, because the backend is reached
/// at a different host from the simulator, the Android emulator and a phone on
/// the LAN — so it cannot know its own public address. Resolving here, at
/// render time rather than at parse time, also means a cached recipe still
/// loads after the base URL changes.
String? resolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') ||
      url.startsWith('https://') ||
      url.startsWith('data:')) {
    return url;
  }
  final base = AppConstants.apiBaseUrl;
  return url.startsWith('/') ? '$base$url' : '$base/$url';
}

/// Renders a recipe photo with the three states the design needs: loading,
/// loaded, and "no photo yet".
///
/// [isGenerating] is for AI recipes whose image is still being produced — it
/// shows a shimmering placeholder rather than the empty-state icon, so the
/// user can tell the difference between "coming" and "none".
class RecipeImage extends StatelessWidget {
  final String? url;
  final bool isGenerating;
  final BoxFit fit;

  const RecipeImage({
    super.key,
    required this.url,
    this.isGenerating = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = resolveImageUrl(url);

    if (resolved == null) {
      return isGenerating ? const _GeneratingPlaceholder() : const _EmptyImage();
    }

    // Older recipes may still hold an inline data URI from before images were
    // written to disk. Kept so those keep rendering rather than breaking.
    if (resolved.startsWith('data:image')) {
      try {
        final base64Part = resolved.split(',').last;
        return Image.memory(
          base64Decode(base64Part),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => const _EmptyImage(),
        );
      } catch (_) {
        return const _EmptyImage();
      }
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => const _LoadingImage(),
      // The design images are remote and can expire; a broken URL must degrade
      // to the placeholder rather than a Flutter error box.
      errorWidget: (_, _, _) => const _EmptyImage(),
    );
  }
}

class _LoadingImage extends StatelessWidget {
  const _LoadingImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryFixedDim,
        ),
      ),
    );
  }
}

class _EmptyImage extends StatelessWidget {
  const _EmptyImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: const Icon(
        Symbols.restaurant,
        size: 32,
        color: AppColors.outlineVariant,
      ),
    );
  }
}

/// A soft pulse while the backend generates the photo.
class _GeneratingPlaceholder extends StatefulWidget {
  const _GeneratingPlaceholder();

  @override
  State<_GeneratingPlaceholder> createState() => _GeneratingPlaceholderState();
}

class _GeneratingPlaceholderState extends State<_GeneratingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          color: Color.lerp(
            AppColors.surfaceContainer,
            AppColors.secondaryContainer,
            _controller.value,
          ),
          alignment: Alignment.center,
          child: Icon(
            Symbols.magic_button,
            size: 28,
            color: AppColors.primary.withValues(
              alpha: 0.35 + (_controller.value * 0.35),
            ),
          ),
        );
      },
    );
  }
}
