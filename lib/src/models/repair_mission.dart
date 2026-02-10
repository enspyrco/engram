import 'package:meta/meta.dart';

/// A repair mission auto-generated after a network fracture (Tier 3).
///
/// Contains the specific concepts that need review to reconnect the fractured
/// islands. Concepts reviewed during an active mission earn 1.5x mastery credit.
@immutable
class RepairMission {
  const RepairMission({
    required this.id,
    required this.conceptIds,
    this.reviewedConceptIds = const [],
    required this.createdAt,
    this.completedAt,
    this.catastropheEventId,
  });

  factory RepairMission.fromJson(Map<String, dynamic> json) {
    return RepairMission(
      id: json['id'] as String,
      conceptIds:
          (json['conceptIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      reviewedConceptIds:
          (json['reviewedConceptIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
      createdAt: json['createdAt'] as String,
      completedAt: json['completedAt'] as String?,
      catastropheEventId: json['catastropheEventId'] as String?,
    );
  }

  final String id;

  /// Concept IDs that need to be reviewed to complete the mission.
  final List<String> conceptIds;

  /// Concept IDs that have been reviewed so far.
  final List<String> reviewedConceptIds;

  final String createdAt;
  final String? completedAt;
  final String? catastropheEventId;

  bool get isComplete => completedAt != null;

  /// Progress as a fraction (0.0 – 1.0).
  double get progress {
    if (conceptIds.isEmpty) return 1.0;
    return reviewedConceptIds.length / conceptIds.length;
  }

  /// Number of concepts remaining.
  int get remaining => conceptIds.length - reviewedConceptIds.length;

  RepairMission withReviewedConcept(String conceptId) {
    if (reviewedConceptIds.contains(conceptId)) return this;
    final updated = [...reviewedConceptIds, conceptId];
    return RepairMission(
      id: id,
      conceptIds: conceptIds,
      reviewedConceptIds: updated,
      createdAt: createdAt,
      completedAt:
          updated.length >= conceptIds.length
              ? DateTime.now().toUtc().toIso8601String()
              : null,
      catastropheEventId: catastropheEventId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conceptIds': conceptIds,
        'reviewedConceptIds': reviewedConceptIds,
        'createdAt': createdAt,
        'completedAt': completedAt,
        'catastropheEventId': catastropheEventId,
      };
}
