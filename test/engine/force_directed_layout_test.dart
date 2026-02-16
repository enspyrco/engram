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

    test('initialPositions preserves pre-seeded positions', () {
      const seeded0 = Offset(200, 150);
      const seeded1 = Offset(400, 300);

      final layout = ForceDirectedLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        seed: 42,
        initialPositions: [seeded0, seeded1, null, null],
      );

      // Pre-seeded positions appear verbatim before any steps
      expect(layout.positions[0], seeded0);
      expect(layout.positions[1], seeded1);
      // New nodes got random positions (not zero)
      expect(layout.positions[2], isNot(Offset.zero));
      expect(layout.positions[3], isNot(Offset.zero));
    });

    test('initialPositions reduces temperature', () {
      final full = ForceDirectedLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        seed: 42,
      );
      final incremental = ForceDirectedLayout(
        nodeCount: 4,
        edges: [(0, 1), (1, 2), (2, 3)],
        seed: 42,
        initialPositions: [
          const Offset(100, 100),
          const Offset(200, 200),
          const Offset(300, 300),
          null, // one new node
        ],
      );

      // Incremental layout should settle faster (lower starting temperature)
      var fullSteps = 0;
      while (full.step()) {
        fullSteps++;
      }
      var incrSteps = 0;
      while (incremental.step()) {
        incrSteps++;
      }
      expect(incrSteps, lessThan(fullSteps));
    });

    test('initialPositions null behaves like no argument', () {
      final withNull = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 42,
        initialPositions: null,
      );
      final without = ForceDirectedLayout(
        nodeCount: 3,
        edges: [(0, 1), (1, 2)],
        seed: 42,
      );

      // Same initial positions
      for (var i = 0; i < 3; i++) {
        expect(withNull.positions[i], without.positions[i]);
      }
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

      const margin = 30.0; // matches engine hard clamp margin
      for (final pos in layout.positions) {
        expect(pos.dx, greaterThanOrEqualTo(margin));
        expect(pos.dx, lessThanOrEqualTo(400 - margin));
        expect(pos.dy, greaterThanOrEqualTo(margin));
        expect(pos.dy, lessThanOrEqualTo(300 - margin));
      }
    });
  });
}
