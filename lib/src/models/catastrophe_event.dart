import 'package:meta/meta.dart';

import 'network_health.dart';

/// A recorded catastrophe event in the team's history.
@immutable
class CatastropheEvent {
  const CatastropheEvent({
    required this.id,
    required this.tier,
    required this.affectedConceptIds,
    required this.createdAt,
    this.resolvedAt,
    this.clusterLabel,
  });

  factory CatastropheEvent.fromJson(Map<String, dynamic> json) {
    return CatastropheEvent(
      id: json['id'] as String,
      tier: HealthTier.values.byName(json['tier'] as String),
      affectedConceptIds: (json['affectedConceptIds'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      createdAt: json['createdAt'] as String,
      resolvedAt: json['resolvedAt'] as String?,
      clusterLabel: json['clusterLabel'] as String?,
    );
  }

  final String id;
  final HealthTier tier;
  final List<String> affectedConceptIds;
  final String createdAt;
  final String? resolvedAt;
  final String? clusterLabel;

  bool get isResolved => resolvedAt != null;

  CatastropheEvent withResolved(String timestamp) => CatastropheEvent(
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
        'affectedConceptIds': affectedConceptIds,
        'createdAt': createdAt,
        'resolvedAt': resolvedAt,
        'clusterLabel': clusterLabel,
      };
}
