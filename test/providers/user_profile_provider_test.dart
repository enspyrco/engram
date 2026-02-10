import 'package:engram/src/models/user_profile.dart';
import 'package:engram/src/storage/user_profile_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  group('UserProfileRepository', () {
    late FakeFirebaseFirestore firestore;
    late UserProfileRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = UserProfileRepository(
        firestore: firestore,
        userId: 'user1',
      );
    });

    test('load returns null when no profile exists', () async {
      final profile = await repo.load();
      expect(profile, isNull);
    });

    test('save and load round-trips correctly', () async {
      const profile = UserProfile(
        uid: 'user1',
        displayName: 'Alice',
        email: 'alice@example.com',
        photoUrl: 'https://photo.url/alice.jpg',
        currentStreak: 5,
        createdAt: '2025-01-01T00:00:00.000Z',
      );

      await repo.save(profile);
      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded!.uid, 'user1');
      expect(loaded.displayName, 'Alice');
      expect(loaded.email, 'alice@example.com');
      expect(loaded.photoUrl, 'https://photo.url/alice.jpg');
      expect(loaded.currentStreak, 5);
    });

    test('updateWikiUrl updates only the wiki URL field', () async {
      const profile = UserProfile(
        uid: 'user1',
        displayName: 'Alice',
        currentStreak: 0,
        createdAt: '2025-01-01T00:00:00.000Z',
      );
      await repo.save(profile);

      await repo.updateWikiUrl('https://wiki.example.com');
      final loaded = await repo.load();

      expect(loaded!.wikiUrl, 'https://wiki.example.com');
      expect(loaded.displayName, 'Alice');
    });

    test('updateLastSession updates timestamp and streak', () async {
      const profile = UserProfile(
        uid: 'user1',
        displayName: 'Alice',
        currentStreak: 0,
        createdAt: '2025-01-01T00:00:00.000Z',
      );
      await repo.save(profile);

      await repo.updateLastSession(
        timestamp: '2025-06-15T10:00:00.000Z',
        streak: 7,
      );
      final loaded = await repo.load();

      expect(loaded!.lastSessionAt, '2025-06-15T10:00:00.000Z');
      expect(loaded.currentStreak, 7);
    });

    test('watch emits profile updates', () async {
      const profile = UserProfile(
        uid: 'user1',
        displayName: 'Alice',
        currentStreak: 0,
        createdAt: '2025-01-01T00:00:00.000Z',
      );

      await repo.save(profile);

      // After saving, the first emission should be the saved profile
      final watched = await repo.watch().first;

      expect(watched, isNotNull);
      expect(watched!.displayName, 'Alice');
    });
  });

  group('UserProfile model', () {
    test('fromJson/toJson round-trip', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'Bob',
        email: 'bob@test.com',
        photoUrl: null,
        wikiUrl: 'https://wiki.test.com',
        lastSessionAt: '2025-03-01T12:00:00.000Z',
        currentStreak: 3,
        createdAt: '2025-01-01T00:00:00.000Z',
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.uid, 'u1');
      expect(restored.displayName, 'Bob');
      expect(restored.email, 'bob@test.com');
      expect(restored.photoUrl, isNull);
      expect(restored.wikiUrl, 'https://wiki.test.com');
      expect(restored.currentStreak, 3);
    });

    test('withWikiUrl creates new instance', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'Bob',
        currentStreak: 0,
        createdAt: '2025-01-01T00:00:00.000Z',
      );

      final updated = profile.withWikiUrl('https://wiki.new.com');
      expect(updated.wikiUrl, 'https://wiki.new.com');
      expect(updated.displayName, 'Bob');
      expect(profile.wikiUrl, isNull); // original unchanged
    });

    test('withLastSession creates new instance', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'Bob',
        currentStreak: 0,
        createdAt: '2025-01-01T00:00:00.000Z',
      );

      final updated = profile.withLastSession(
        timestamp: '2025-06-15T10:00:00.000Z',
        streak: 5,
      );
      expect(updated.lastSessionAt, '2025-06-15T10:00:00.000Z');
      expect(updated.currentStreak, 5);
      expect(profile.currentStreak, 0); // original unchanged
    });
  });
}
