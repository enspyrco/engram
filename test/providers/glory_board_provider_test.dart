import 'package:engram/src/models/glory_entry.dart';
import 'package:test/test.dart';

void main() {
  group('GloryEntry sorting', () {
    test('entries sort by totalPoints descending', () {
      final entries = [
        const GloryEntry(
          uid: 'user1',
          displayName: 'Alice',
          guardianPoints: 5,
          missionPoints: 3,
          goalPoints: 2,
        ),
        const GloryEntry(
          uid: 'user2',
          displayName: 'Bob',
          guardianPoints: 10,
          missionPoints: 8,
          goalPoints: 5,
        ),
        const GloryEntry(
          uid: 'user3',
          displayName: 'Carol',
          guardianPoints: 0,
          missionPoints: 1,
          goalPoints: 0,
        ),
      ];

      final sorted = List<GloryEntry>.of(entries)
        ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

      expect(sorted[0].uid, 'user2'); // 23 points
      expect(sorted[1].uid, 'user1'); // 10 points
      expect(sorted[2].uid, 'user3'); // 1 point
    });

    test('totalPoints equals sum of all point categories', () {
      const entry = GloryEntry(
        uid: 'u1',
        displayName: 'Test',
        guardianPoints: 7,
        missionPoints: 3,
        goalPoints: 5,
      );

      expect(entry.totalPoints, 15);
    });

    test('entries with zero points sort last', () {
      final entries = [
        const GloryEntry(uid: 'u1', displayName: 'Zero'),
        const GloryEntry(
          uid: 'u2',
          displayName: 'Hero',
          guardianPoints: 1,
        ),
      ];

      final sorted = List<GloryEntry>.of(entries)
        ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

      expect(sorted[0].uid, 'u2');
      expect(sorted[1].uid, 'u1');
    });
  });
}
