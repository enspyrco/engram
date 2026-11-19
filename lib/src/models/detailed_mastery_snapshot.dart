import 'package:meta/meta.dart';

import '../engine/mastery_state.dart';
import 'mastery_snapshot.dart';

/// Per-concept mastery data shared with teammates for graph overlay rendering.
///
/// Extends the lightweight [MasterySnapshot] (aggregate counts) with a
/// concept-level breakdown so teammates' avatars can be positioned near
/// the specific concepts they've mastered on the force-directed graph.
@immutable
class DetailedMasterySnapshot {
  const DetailedMasterySnapshot({
    required this.summary,
    this.conceptMastery = const {},
    this.updatedAt,
  });

  factory DetailedMasterySnapshot.fromJson(Map<String, dynamic> json) {
    final masteryByName = MasteryState.values.asNameMap();
    return DetailedMasterySnapshot(
      summary:
          json['summary'] != null
              ? MasterySnapshot.fromJson(
                json['summary'] as Map<String, dynamic>,
              )
              : const MasterySnapshot(),
      // Unknown state names (from a newer client) are dropped.
      conceptMastery: {
        for (final MapEntry(:key, :value)
            in (json['conceptMastery'] as Map<String, dynamic>? ?? const {})
                .entries)
          if (masteryByName[value] case final state?) key: state,
      },
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
    );
  }

  /// Aggregate mastery counts (same as the existing lightweight snapshot).
  final MasterySnapshot summary;

  /// Maps conceptId to its mastery state.
  /// Only includes concepts that are not [MasteryState.locked], to keep the
  /// payload small.
  final Map<String, MasteryState> conceptMastery;

  /// Timestamp of when this snapshot was last updated.
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'summary': summary.toJson(),
    'conceptMastery': {
      for (final MapEntry(:key, :value) in conceptMastery.entries)
        key: value.name,
    },
    'updatedAt': updatedAt?.toIso8601String(),
  };

  /// Concept IDs where this friend has mastered state.
  List<String> get masteredConceptIds =>
      conceptMastery.entries
          .where((e) => e.value == MasteryState.mastered)
          .map((e) => e.key)
          .toList();

  /// Concept IDs where this friend is actively learning.
  List<String> get learningConceptIds =>
      conceptMastery.entries
          .where((e) => e.value == MasteryState.learning)
          .map((e) => e.key)
          .toList();
}
