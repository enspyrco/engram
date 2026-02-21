import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import 'network_health.dart';

/// A recorded catastrophe event in the team's history.
@immutable
class CatastropheEvent {
  CatastropheEvent({
    required this.id,
    required this.tier,
    List<String> affectedConceptIds = const [],
    required this.createdAt,
    this.resolvedAt,
    this.clusterLabel,
  }) : affectedConceptIds = IList(affectedConceptIds);

  const CatastropheEvent._raw({
    required this.id,
    required this.tier,
    required this.affectedConceptIds,
    required this.createdAt,
    this.resolvedAt,
    this.clusterLabel,
  });

  factory CatastropheEvent.fromJson(Map<String, dynamic> json) {
    return CatastropheEvent._raw(
      id: json['id'] as String,
      tier: HealthTier.values.byName(json['tier'] as String),
      affectedConceptIds:
          (json['affectedConceptIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toIList() ??
          const IListConst([]),
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt:
          json['resolvedAt'] != null
              ? DateTime.parse(json['resolvedAt'] as String)
              : null,
      clusterLabel: json['clusterLabel'] as String?,
    );
  }

  final String id;
  final HealthTier tier;
  final IList<String> affectedConceptIds;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? clusterLabel;

  bool get isResolved => resolvedAt != null;

  CatastropheEvent withResolved(DateTime timestamp) => CatastropheEvent._raw(
    id: id,
    tier: tier,
    affectedConceptIds: affectedConceptIds,
    createdAt: createdAt,
    resolvedAt: timestamp,
    clusterLabel: clusterLabel,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tier': tier.name,
    'affectedConceptIds': affectedConceptIds.toList(),
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'clusterLabel': clusterLabel,
  };
}
