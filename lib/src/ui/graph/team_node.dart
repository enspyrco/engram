import 'dart:ui';

import '../../models/detailed_mastery_snapshot.dart';
import '../../models/friend.dart';

/// A team member node in the force-directed graph.
///
/// Rendered as a circular avatar photo with a health ring. Positioned near
/// concepts the friend has mastered, with weaker spring constants so avatars
/// orbit the periphery of concept clusters.
class TeamNode {
  TeamNode({
    required this.friend,
    required this.detailedSnapshot,
    this.position = Offset.zero,
    this.radius = 24.0,
  });

  final Friend friend;
  final DetailedMasterySnapshot detailedSnapshot;
  Offset position;
  final double radius;

  String get id => 'team_${friend.uid}';
  String get displayName => friend.displayName;
  String? get photoUrl => friend.photoUrl;

  /// Concept IDs this friend has mastered (drives edge connections on graph).
  List<String> get masteredConceptIds => detailedSnapshot.masteredConceptIds;

  /// Concept IDs this friend is actively learning.
  List<String> get learningConceptIds => detailedSnapshot.learningConceptIds;

  /// Health ratio: fraction of known concepts that are mastered vs total known.
  double get healthRatio {
    final total = detailedSnapshot.conceptMastery.length;
    if (total == 0) return 0.0;
    return masteredConceptIds.length / total;
  }

  /// Whether a screen-space point falls within this node's circle.
  bool containsPoint(Offset point) {
    return (point - position).distance <= radius;
  }
}
