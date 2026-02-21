import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

/// A community of related concepts detected via label propagation.
///
/// Used for guardian assignments, fracture visualization, and per-cluster
/// health scoring.
@immutable
class ConceptCluster {
  ConceptCluster({
    required this.label,
    List<String> conceptIds = const [],
    this.guardianUid,
  }) : conceptIds = IList(conceptIds);

  const ConceptCluster._raw({
    required this.label,
    required this.conceptIds,
    this.guardianUid,
  });

  factory ConceptCluster.fromJson(Map<String, dynamic> json) {
    return ConceptCluster._raw(
      label: json['label'] as String,
      conceptIds:
          (json['conceptIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toIList() ??
          const IListConst([]),
      guardianUid: json['guardianUid'] as String?,
    );
  }

  /// Human-readable label (derived from most common concept name in cluster).
  final String label;

  /// The concept IDs that belong to this cluster.
  final IList<String> conceptIds;

  /// UID of the team member guarding this cluster (optional).
  final String? guardianUid;

  bool get hasGuardian => guardianUid != null;

  ConceptCluster withGuardian(String? uid) => ConceptCluster._raw(
    label: label,
    conceptIds: conceptIds,
    guardianUid: uid,
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'conceptIds': conceptIds.toList(),
    'guardianUid': guardianUid,
  };
}
