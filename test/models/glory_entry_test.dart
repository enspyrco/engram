import 'package:engram/src/models/glory_entry.dart';
import 'package:test/test.dart';

void main() {
  group('GloryEntry', () {
    test('fromJson/toJson round-trip', () {
      const entry = GloryEntry(
        uid: 'user1',
        displayName: 'Alice',
        photoUrl: 'https://photo.url/alice.jpg',
        guardianPoints: 10,
        missionPoints: 5,
        goalPoints: 3,
      );

      final json = entry.toJson();
      final restored = GloryEntry.fromJson(json);

      expect(restored.uid, 'user1');
      expect(restored.displayName, 'Alice');
      expect(restored.photoUrl, 'https://photo.url/alice.jpg');
      expect(restored.guardianPoints, 10);
      expect(restored.missionPoints, 5);
      expect(restored.goalPoints, 3);
    });

    test('totalPoints sums all categories', () {
      const entry = GloryEntry(
        uid: 'user1',
        displayName: 'Alice',
        guardianPoints: 10,
        missionPoints: 5,
        goalPoints: 3,
      );

      expect(entry.totalPoints, 18);
    });

    test('totalPoints is zero by default', () {
      const entry = GloryEntry(uid: 'user1', displayName: 'Alice');
      expect(entry.totalPoints, 0);
    });

    test('fromJson handles missing optional fields', () {
      final entry = GloryEntry.fromJson(const {
        'uid': 'user1',
        'displayName': 'Bob',
      });

      expect(entry.photoUrl, isNull);
      expect(entry.guardianPoints, 0);
      expect(entry.missionPoints, 0);
      expect(entry.goalPoints, 0);
    });

    test('withGuardianPoints creates new instance', () {
      const entry = GloryEntry(
        uid: 'user1',
        displayName: 'Alice',
        guardianPoints: 5,
        missionPoints: 3,
      );

      final updated = entry.withGuardianPoints(15);
      expect(updated.guardianPoints, 15);
      expect(updated.missionPoints, 3); // unchanged
      expect(entry.guardianPoints, 5); // original unchanged
    });

    test('withMissionPoints creates new instance', () {
      const entry = GloryEntry(
        uid: 'user1',
        displayName: 'Alice',
        missionPoints: 3,
      );

      final updated = entry.withMissionPoints(10);
      expect(updated.missionPoints, 10);
      expect(entry.missionPoints, 3);
    });

    test('withGoalPoints creates new instance', () {
      const entry = GloryEntry(
        uid: 'user1',
        displayName: 'Alice',
        goalPoints: 2,
      );

      final updated = entry.withGoalPoints(8);
      expect(updated.goalPoints, 8);
      expect(entry.goalPoints, 2);
    });
  });
}
