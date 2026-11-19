import 'package:engram/src/crdt/node_id_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NodeIdRepository', () {
    late NodeIdRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = NodeIdRepository(prefs);
    });

    test('generates a new UUID on first access', () {
      final nodeId = repo.nodeId;
      expect(nodeId, isNotEmpty);
      // UUID v4 format: 8-4-4-4-12 hex characters
      expect(
        nodeId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('returns the same node ID on subsequent accesses', () {
      final first = repo.nodeId;
      final second = repo.nodeId;
      expect(second, equals(first));
    });

    test('persists node ID across repository instances', () async {
      final firstId = repo.nodeId;

      // Create a new repository with the same SharedPreferences backing
      final prefs = await SharedPreferences.getInstance();
      final repo2 = NodeIdRepository(prefs);
      expect(repo2.nodeId, equals(firstId));
    });

    test('uses existing node ID from SharedPreferences', () async {
      const existingId = '12345678-1234-4321-abcd-123456789abc';
      SharedPreferences.setMockInitialValues({
        NodeIdRepository.prefsKey: existingId,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo2 = NodeIdRepository(prefs);
      expect(repo2.nodeId, equals(existingId));
    });

    group('ensureInitialized', () {
      test('generates and persists node ID with awaited write', () async {
        await repo.ensureInitialized();
        final nodeId = repo.nodeId;
        expect(nodeId, isNotEmpty);

        // Verify it was persisted by creating a new instance
        final prefs = await SharedPreferences.getInstance();
        final repo2 = NodeIdRepository(prefs);
        expect(repo2.nodeId, equals(nodeId));
      });

      test('is idempotent — second call is a no-op', () async {
        await repo.ensureInitialized();
        final first = repo.nodeId;
        await repo.ensureInitialized();
        expect(repo.nodeId, equals(first));
      });

      test(
        'nodeId getter returns same value after ensureInitialized',
        () async {
          await repo.ensureInitialized();
          final fromGetter = repo.nodeId;
          expect(fromGetter, isNotEmpty);
          // Call again to verify cache consistency
          expect(repo.nodeId, equals(fromGetter));
        },
      );
    });
  });
}
