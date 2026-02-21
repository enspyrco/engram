import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/detailed_mastery_snapshot.dart';
import '../ui/graph/team_node.dart';
import 'friends_provider.dart';

/// Provides the list of [TeamNode]s for rendering on the force-directed graph.
///
/// Merges friends from [friendsProvider] with their detailed mastery snapshots.
/// Each friend with a non-empty [DetailedMasterySnapshot] becomes a team node
/// positioned on the graph near the concepts they've mastered.
final teamGraphProvider = Provider<List<TeamNode>>((ref) {
  final friends = ref.watch(friendsProvider).valueOrNull ?? [];
  final snapshots = ref.watch(teamSnapshotsProvider);

  final nodes = <TeamNode>[];
  for (final friend in friends) {
    final snapshot = snapshots[friend.uid];
    if (snapshot == null || snapshot.conceptMastery.isEmpty) continue;
    nodes.add(TeamNode(friend: friend, detailedSnapshot: snapshot));
  }
  return nodes;
});

/// Holds detailed mastery snapshots keyed by friend UID.
///
/// Updated when the social repository streams new snapshot data.
/// In a real deployment, this watches Firestore streams from
/// `wikiGroups/{hash}/memberSnapshots/{uid}`.
final teamSnapshotsProvider = NotifierProvider<
  TeamSnapshotsNotifier,
  Map<String, DetailedMasterySnapshot>
>(TeamSnapshotsNotifier.new);

class TeamSnapshotsNotifier
    extends Notifier<Map<String, DetailedMasterySnapshot>> {
  @override
  Map<String, DetailedMasterySnapshot> build() {
    return {};
  }

  /// Update a single friend's detailed snapshot (called after Firestore stream
  /// delivers new data).
  void updateSnapshot(String uid, DetailedMasterySnapshot snapshot) {
    state = {...state, uid: snapshot};
  }

  /// Bulk update from a Firestore stream event.
  void setSnapshots(Map<String, DetailedMasterySnapshot> snapshots) {
    state = snapshots;
  }
}
