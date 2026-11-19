import 'package:drift/native.dart';
import 'package:engram/src/storage/drift/drift_graph_repository.dart';
import 'package:engram/src/storage/drift/engram_database.dart';
import 'package:test/test.dart';

void main() {
  late EngramDatabase db;
  late DriftGraphRepository repo;

  setUp(() {
    db = EngramDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGraphRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('sync metadata CRUD', () {
    test('getLastSyncedHlc returns null for unknown peer', () async {
      final hlc = await repo.getLastSyncedHlc('unknown-peer');
      expect(hlc, isNull);
    });

    test('updateLastSyncedHlc creates a new row', () async {
      await repo.updateLastSyncedHlc(
        'peer-1',
        '2026-01-01T00:00:00.000Z-0000-peer-1',
      );

      final hlc = await repo.getLastSyncedHlc('peer-1');
      expect(hlc, '2026-01-01T00:00:00.000Z-0000-peer-1');
    });

    test('updateLastSyncedHlc upserts existing row', () async {
      await repo.updateLastSyncedHlc(
        'peer-1',
        '2026-01-01T00:00:00.000Z-0000-peer-1',
      );
      await repo.updateLastSyncedHlc(
        'peer-1',
        '2026-02-01T00:00:00.000Z-0000-peer-1',
      );

      final hlc = await repo.getLastSyncedHlc('peer-1');
      expect(hlc, '2026-02-01T00:00:00.000Z-0000-peer-1');
    });

    test('tracks multiple peers independently', () async {
      await repo.updateLastSyncedHlc('peer-1', 'hlc-1');
      await repo.updateLastSyncedHlc('peer-2', 'hlc-2');

      expect(await repo.getLastSyncedHlc('peer-1'), 'hlc-1');
      expect(await repo.getLastSyncedHlc('peer-2'), 'hlc-2');
    });
  });
}
