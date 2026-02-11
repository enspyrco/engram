import 'package:engram/src/ui/graph/storm_overlay_painter.dart';
import 'package:test/test.dart';

void main() {
  group('StormOverlayPainter', () {
    test('shouldRepaint detects animation progress changes', () {
      final painter1 = StormOverlayPainter(
        edges: const [],
        animationProgress: 0.0,
      );
      final painter2 = StormOverlayPainter(
        edges: const [],
        animationProgress: 0.5,
      );
      final painter3 = StormOverlayPainter(
        edges: const [],
        animationProgress: 0.0,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isFalse);
    });

    test('shouldRepaint detects intensity changes', () {
      final painter1 = StormOverlayPainter(
        edges: const [],
        animationProgress: 0.0,
        intensity: 1.0,
      );
      final painter2 = StormOverlayPainter(
        edges: const [],
        animationProgress: 0.0,
        intensity: 0.5,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('default intensity is 1.0', () {
      final painter = StormOverlayPainter(
        edges: const [],
        animationProgress: 0.0,
      );

      expect(painter.intensity, 1.0);
    });
  });
}
