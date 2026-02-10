import 'package:meta/meta.dart';

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
    return DetailedMasterySnapshot(
      summary: json['summary'] != null
          ? MasterySnapshot.fromJson(json['summary'] as Map<String, dynamic>)
          : const MasterySnapshot(),
      conceptMastery:
          (json['conceptMastery'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v as String),
              ) ??
              const {},
      updatedAt: json['updatedAt'] as String?,
    );
  }

  /// Aggregate mastery counts (same as the existing lightweight snapshot).
  final MasterySnapshot summary;

  /// Maps conceptId to MasteryState name (e.g. 'mastered', 'learning').
  /// Only includes concepts with state != 'locked' to keep payload small.
  final Map<String, String> conceptMastery;

  /// ISO8601 timestamp of when this snapshot was last updated.
  final String? updatedAt;

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'conceptMastery': conceptMastery,
        'updatedAt': updatedAt,
      };

  /// Concept IDs where this friend has mastered state.
  List<String> get masteredConceptIds => conceptMastery.entries
      .where((e) => e.value == 'mastered')
      .map((e) => e.key)
      .toList();

  /// Concept IDs where this friend is actively learning.
  List<String> get learningConceptIds => conceptMastery.entries
      .where((e) => e.value == 'learning')
      .map((e) => e.key)
      .toList();
}
