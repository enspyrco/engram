import 'package:engram/src/models/detailed_mastery_snapshot.dart';
import 'package:engram/src/models/friend.dart';
import 'package:engram/src/models/mastery_snapshot.dart';
import 'package:engram/src/providers/friends_provider.dart';
import 'package:engram/src/providers/team_graph_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('TeamGraphProvider', () {
    test('produces TeamNodes for friends with non-empty snapshots', () async {
      final container = ProviderContainer(
        overrides: [
          friendsProvider.overrideWith(() => _FixedFriendsNotifier([
                const Friend(uid: 'u1', displayName: 'Alice'),
                const Friend(uid: 'u2', displayName: 'Bob'),
                const Friend(uid: 'u3', displayName: 'Charlie'),
              ])),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the async friends provider to resolve
      await container.read(friendsProvider.future);

      // Set snapshots: Alice has mastery data, Bob has empty, Charlie has data
      container.read(teamSnapshotsProvider.notifier).setSnapshots({
        'u1': const DetailedMasterySnapshot(
          summary: MasterySnapshot(totalConcepts: 5, mastered: 3),
          conceptMastery: {'c1': 'mastered', 'c2': 'learning'},
        ),
        // u2 intentionally missing
        'u3': const DetailedMasterySnapshot(
          summary: MasterySnapshot(totalConcepts: 2, mastered: 1),
          conceptMastery: {'c1': 'mastered'},
        ),
      });

      final teamNodes = container.read(teamGraphProvider);

      // Bob has no snapshot → excluded. Alice and Charlie included.
      expect(teamNodes, hasLength(2));
      expect(teamNodes.map((n) => n.displayName), containsAll(['Alice', 'Charlie']));
    });

    test('excludes friends with empty conceptMastery', () async {
      final container = ProviderContainer(
        overrides: [
          friendsProvider.overrideWith(() => _FixedFriendsNotifier([
                const Friend(uid: 'u1', displayName: 'Alice'),
              ])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(friendsProvider.future);

      container.read(teamSnapshotsProvider.notifier).setSnapshots({
        'u1': const DetailedMasterySnapshot(
          summary: MasterySnapshot(totalConcepts: 5, mastered: 3),
          conceptMastery: {}, // empty
        ),
      });

      final teamNodes = container.read(teamGraphProvider);
      expect(teamNodes, isEmpty);
    });

    test('TeamNode healthRatio computes correctly', () async {
      final container = ProviderContainer(
        overrides: [
          friendsProvider.overrideWith(() => _FixedFriendsNotifier([
                const Friend(uid: 'u1', displayName: 'Alice'),
              ])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(friendsProvider.future);

      container.read(teamSnapshotsProvider.notifier).setSnapshots({
        'u1': const DetailedMasterySnapshot(
          summary: MasterySnapshot(totalConcepts: 4, mastered: 2),
          conceptMastery: {
            'c1': 'mastered',
            'c2': 'mastered',
            'c3': 'learning',
            'c4': 'due',
          },
        ),
      });

      final teamNodes = container.read(teamGraphProvider);
      expect(teamNodes.first.healthRatio, closeTo(0.5, 0.01)); // 2/4
    });

    test('returns empty list when no friends', () async {
      final container = ProviderContainer(
        overrides: [
          friendsProvider.overrideWith(() => _FixedFriendsNotifier([])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(friendsProvider.future);

      final teamNodes = container.read(teamGraphProvider);
      expect(teamNodes, isEmpty);
    });
  });
}

class _FixedFriendsNotifier extends AsyncNotifier<List<Friend>>
    implements FriendsNotifier {
  _FixedFriendsNotifier(this._friends);
  final List<Friend> _friends;

  @override
  Future<List<Friend>> build() async => _friends;
}
