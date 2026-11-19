import 'package:crdt/crdt.dart';
import 'package:engram/src/crdt/hlc_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HlcManager', () {
    const nodeId = 'test-node-001';
    late HlcManager manager;

    setUp(() {
      manager = HlcManager(nodeId: nodeId);
    });

    test('now() returns an HLC with the correct node ID', () {
      final hlc = manager.now();
      expect(hlc.nodeId, equals(nodeId));
    });

    test('now() returns monotonically increasing timestamps', () {
      final first = manager.now();
      final second = manager.now();
      expect(second > first, isTrue);
    });

    test('now() increments counter for same-millisecond events', () {
      // Use a fixed wall time to force counter increment
      final fixedTime = DateTime.utc(2026, 2, 25, 12, 0, 0);
      final first = manager.now(wallTime: fixedTime);
      final second = manager.now(wallTime: fixedTime);

      expect(first.dateTime, equals(second.dateTime));
      expect(second.counter, greaterThan(first.counter));
    });

    test('receive() merges with a remote HLC', () {
      manager.now(); // advance local clock
      // Simulate a remote clock that is ahead
      final futureTime = DateTime.now().toUtc().add(const Duration(seconds: 5));
      final remote = Hlc(futureTime, 0, 'remote-node-002');

      final merged = manager.receive(remote);
      expect(merged.nodeId, equals(nodeId));
      expect(
        merged >= remote,
        isTrue,
        reason: 'Merged HLC should be at least as high as the remote',
      );
    });

    test('receive() preserves monotonicity when remote is behind', () {
      // Advance local clock
      manager.now(); // advance once
      final local2 = manager.now();

      // Create a remote HLC that is behind
      final oldRemote = Hlc(DateTime.utc(2020, 1, 1), 0, 'remote-node-002');

      final afterReceive = manager.receive(oldRemote);
      expect(
        afterReceive >= local2,
        isTrue,
        reason: 'Should not go backward after receiving an old HLC',
      );
    });

    test('canonical time tracks the highest HLC seen', () {
      final hlc1 = manager.now();
      expect(manager.canonicalTime, equals(hlc1));

      final hlc2 = manager.now();
      expect(manager.canonicalTime, equals(hlc2));
      expect(manager.canonicalTime > hlc1, isTrue);
    });

    test('HLC string round-trips correctly', () {
      final original = manager.now();
      final serialized = original.toString();
      final parsed = Hlc.parse(serialized);

      expect(parsed.dateTime, equals(original.dateTime));
      expect(parsed.counter, equals(original.counter));
      expect(parsed.nodeId, equals(original.nodeId));
      expect(parsed, equals(original));
    });

    test('HLC toJson and parse are symmetric', () {
      final original = manager.now();
      final json = original.toJson();
      final restored = Hlc.parse(json);
      expect(restored, equals(original));
    });

    test('two managers with different node IDs produce distinct HLCs', () {
      final manager2 = HlcManager(nodeId: 'test-node-002');
      final hlc1 = manager.now();
      final hlc2 = manager2.now();
      expect(hlc1.nodeId, isNot(equals(hlc2.nodeId)));
    });
  });
}
