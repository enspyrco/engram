import 'package:meta/meta.dart';

/// The four catastrophe tiers from the game design.
enum HealthTier {
  healthy,   // >= 70%
  brownout,  // < 70%
  cascade,   // < 50%
  fracture,  // < 30%
  collapse,  // < 10%
}

/// Composite network health score for a team's knowledge graph.
@immutable
class NetworkHealth {
  const NetworkHealth({
    required this.score,
    required this.tier,
    this.masteryRatio = 0.0,
    this.learningRatio = 0.0,
    this.avgFreshness = 0.0,
    this.atRiskCriticalPaths = 0,
    this.totalCriticalPaths = 0,
    this.clusterHealth = const {},
  });

  factory NetworkHealth.fromJson(Map<String, dynamic> json) {
    return NetworkHealth(
      score: (json['score'] as num).toDouble(),
      tier: HealthTier.values.byName(json['tier'] as String),
      masteryRatio: (json['masteryRatio'] as num?)?.toDouble() ?? 0.0,
      learningRatio: (json['learningRatio'] as num?)?.toDouble() ?? 0.0,
      avgFreshness: (json['avgFreshness'] as num?)?.toDouble() ?? 0.0,
      atRiskCriticalPaths: json['atRiskCriticalPaths'] as int? ?? 0,
      totalCriticalPaths: json['totalCriticalPaths'] as int? ?? 0,
      clusterHealth: (json['clusterHealth'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
    );
  }

  /// Overall health score (0.0 – 1.0).
  final double score;

  /// Current catastrophe tier.
  final HealthTier tier;

  /// Fraction of concepts in mastered state.
  final double masteryRatio;

  /// Fraction of concepts in learning state.
  final double learningRatio;

  /// Average freshness across all concepts (0.0 – 1.0).
  final double avgFreshness;

  /// Number of critical path concepts (high out-degree) that are at risk.
  final int atRiskCriticalPaths;

  /// Total number of critical path concepts.
  final int totalCriticalPaths;

  /// Per-cluster health scores, keyed by cluster label.
  final Map<String, double> clusterHealth;

  /// Derive the tier from a raw score.
  static HealthTier tierFromScore(double score) {
    if (score < 0.10) return HealthTier.collapse;
    if (score < 0.30) return HealthTier.fracture;
    if (score < 0.50) return HealthTier.cascade;
    if (score < 0.70) return HealthTier.brownout;
    return HealthTier.healthy;
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'tier': tier.name,
        'masteryRatio': masteryRatio,
        'learningRatio': learningRatio,
        'avgFreshness': avgFreshness,
        'atRiskCriticalPaths': atRiskCriticalPaths,
        'totalCriticalPaths': totalCriticalPaths,
        'clusterHealth': clusterHealth,
      };
}
