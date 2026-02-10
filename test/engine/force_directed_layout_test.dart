import 'dart:ui';

import 'package:engram/src/engine/force_directed_layout.dart';
import 'package:test/test.dart';

void main() {
  group('ForceDirectedLayout', () {
    test('positions change after a step (convergence)', () {
      final layout = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 42,
      );

      final before = List<Offset>.from(layout.positions);
      layout.step();
      final after = layout.positions;

      // At least one position should have moved
      final moved = Iterable.generate(3).any(
        (i) => (after[i] - before[i]).distance > 0.01,
      );
      expect(moved, isTrue);
    });

    test('settles after enough steps', () {
      final layout = ForceDirectedLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        seed: 42,
      );

      var steps = 0;
      while (layout.step()) {
        steps++;
        if (steps > 500) break; // safety limit
      }

      expect(layout.isSettled, isTrue);
      expect(steps, lessThan(500));
    });

    test('deterministic with same seed', () {
      final layout1 = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 99,
      );
      final layout2 = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 99,
      );

      // Run both to completion
      while (layout1.step()) {}
      while (layout2.step()) {}

      for (var i = 0; i < 3; i++) {
        expect(layout1.positions[i].dx, closeTo(layout2.positions[i].dx, 0.001));
        expect(layout1.positions[i].dy, closeTo(layout2.positions[i].dy, 0.001));
      }
    });

    test('setPositions overrides layout', () {
      final layout = ForceDirectedLayout(
        nodeCount: 2,
        edges: [(0, 1)],
        seed: 42,
      );

      final custom = [const Offset(100, 100), const Offset(200, 200)];
      layout.setPositions(custom);

      expect(layout.positions[0], const Offset(100, 100));
      expect(layout.positions[1], const Offset(200, 200));
    });

    test('settle() stops the simulation immediately', () {
      final layout = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 42,
      );

      expect(layout.isSettled, isFalse);
      layout.settle();
      expect(layout.isSettled, isTrue);
      expect(layout.step(), isFalse);
    });

    test('single node settles without edges', () {
      final layout = ForceDirectedLayout(
        nodeCount: 1,
        edges: [],
        seed: 42,
      );

      var steps = 0;
      while (layout.step()) {
        steps++;
        if (steps > 500) break;
      }

      expect(layout.isSettled, isTrue);
    });

    test('nodes stay within bounds', () {
      final layout = ForceDirectedLayout(
        nodeCount: 5,
        edges: [(0, 1), (1, 2), (2, 3), (3, 4)],
        width: 400,
        height: 300,
        seed: 42,
      );

      while (layout.step()) {}

      for (final pos in layout.positions) {
        expect(pos.dx, greaterThanOrEqualTo(0));
        expect(pos.dx, lessThanOrEqualTo(400));
        expect(pos.dy, greaterThanOrEqualTo(0));
        expect(pos.dy, lessThanOrEqualTo(300));
      }
    });
  });
}
