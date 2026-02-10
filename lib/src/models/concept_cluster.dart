import 'package:meta/meta.dart';

/// A community of related concepts detected via label propagation.
///
/// Used for guardian assignments, fracture visualization, and per-cluster
/// health scoring.
@immutable
class ConceptCluster {
  const ConceptCluster({
    required this.label,
    required this.conceptIds,
    this.guardianUid,
  });

  factory ConceptCluster.fromJson(Map<String, dynamic> json) {
    return ConceptCluster(
      label: json['label'] as String,
      conceptIds:
          (json['conceptIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      guardianUid: json['guardianUid'] as String?,
    );
  }

  /// Human-readable label (derived from most common concept name in cluster).
  final String label;

  /// The concept IDs that belong to this cluster.
  final List<String> conceptIds;

  /// UID of the team member guarding this cluster (optional).
  final String? guardianUid;

  bool get hasGuardian => guardianUid != null;

  ConceptCluster withGuardian(String? uid) => ConceptCluster(
        label: label,
        conceptIds: conceptIds,
        guardianUid: uid,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'conceptIds': conceptIds,
        'guardianUid': guardianUid,
      };
}
