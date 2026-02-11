import 'package:engram/src/ui/graph/relay_pulse_painter.dart';
import 'package:test/test.dart';

void main() {
  group('RelayPulse', () {
    test('advanced moves progress forward', () {
      const pulse = RelayPulse(
        fromConceptId: 'a',
        toConceptId: 'b',
        progress: 0.5,
        speed: 0.02,
      );

      final next = pulse.advanced();
      expect(next.progress, closeTo(0.52, 0.001));
      expect(next.fromConceptId, 'a');
      expect(next.toConceptId, 'b');
    });

    test('isComplete when progress >= 1.0', () {
      const notDone = RelayPulse(
        fromConceptId: 'a',
        toConceptId: 'b',
        progress: 0.99,
      );
      expect(notDone.isComplete, isFalse);

      const done = RelayPulse(
        fromConceptId: 'a',
        toConceptId: 'b',
        progress: 1.0,
      );
      expect(done.isComplete, isTrue);
    });

    test('default speed is 0.02', () {
      const pulse = RelayPulse(
        fromConceptId: 'a',
        toConceptId: 'b',
        progress: 0.0,
      );
      expect(pulse.speed, 0.02);
    });
  });

  group('RelayPulsePainter', () {
    test('shouldRepaint always returns true', () {
      final painter = RelayPulsePainter(
        pulses: const [],
        edges: const [],
        relayConceptIds: const {},
      );

      expect(painter.shouldRepaint(painter), isTrue);
    });
  });
}
