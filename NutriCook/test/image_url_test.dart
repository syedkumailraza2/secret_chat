import 'package:flutter_test/flutter_test.dart';
import 'package:nutricook/core/constants/app_constants.dart';
import 'package:nutricook/widgets/recipe_image.dart';

void main() {
  final base = AppConstants.apiBaseUrl;

  group('resolveImageUrl', () {
    test('a relative media path is resolved against the API base', () {
      // Generated photos are stored relative, because the backend is reached
      // at a different host from the simulator, the emulator and a phone.
      expect(
        resolveImageUrl('/media/gen-abc123.png'),
        '$base/media/gen-abc123.png',
      );
    });

    test('a path without a leading slash still resolves', () {
      expect(
        resolveImageUrl('media/gen-abc123.png'),
        '$base/media/gen-abc123.png',
      );
    });

    test('an absolute URL is left alone', () {
      // The seeded recipes carry remote https URLs.
      const remote = 'https://lh3.googleusercontent.com/aida-public/AB6AXu';
      expect(resolveImageUrl(remote), remote);
    });

    test('a plain http URL is left alone', () {
      const remote = 'http://example.com/a.png';
      expect(resolveImageUrl(remote), remote);
    });

    test('a data URI is left alone', () {
      // Recipes stored before images moved to disk may still hold one.
      const inline = 'data:image/png;base64,iVBORw0KGgo=';
      expect(resolveImageUrl(inline), inline);
    });

    test('null and empty mean "no photo", not a broken URL', () {
      expect(resolveImageUrl(null), isNull);
      expect(resolveImageUrl(''), isNull);
    });

    test('resolving twice is stable', () {
      // The widget resolves at render time, so this runs on every rebuild.
      final once = resolveImageUrl('/media/x.png');
      expect(resolveImageUrl(once), once);
    });
  });
}
