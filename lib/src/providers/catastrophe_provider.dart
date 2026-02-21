import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../models/catastrophe_event.dart';
import '../models/network_health.dart';
import '../models/repair_mission.dart';
import 'clock_provider.dart';
import 'cluster_provider.dart';
import 'knowledge_graph_provider.dart';
import 'network_health_provider.dart';

const _uuid = Uuid();

/// Immutable snapshot of catastrophe system state.
@immutable
class CatastropheState {
  CatastropheState({
    this.previousTier = HealthTier.healthy,
    List<CatastropheEvent> activeEvents = const [],
    List<RepairMission> activeMissions = const [],
    this.latestTransition,
  }) : activeEvents = IList(activeEvents),
       activeMissions = IList(activeMissions);

  const CatastropheState._raw({
    required this.previousTier,
    required this.activeEvents,
    required this.activeMissions,
    this.latestTransition,
  });

  /// The tier before the most recent health computation.
  final HealthTier previousTier;

  /// Unresolved catastrophe events.
  final IList<CatastropheEvent> activeEvents;

  /// Uncompleted repair missions.
  final IList<RepairMission> activeMissions;

  /// The most recent tier transition (for UI animation triggers).
  /// Null when no transition has occurred yet.
  final TierTransition? latestTransition;

  CatastropheState copyWith({
    HealthTier? previousTier,
    IList<CatastropheEvent>? activeEvents,
    IList<RepairMission>? activeMissions,
    TierTransition? latestTransition,
  }) {
    return CatastropheState._raw(
      previousTier: previousTier ?? this.previousTier,
      activeEvents: activeEvents ?? this.activeEvents,
      activeMissions: activeMissions ?? this.activeMissions,
      latestTransition: latestTransition ?? this.latestTransition,
    );
  }
}

/// Records a tier change with timestamp, for animation sequencing.
@immutable
class TierTransition {
  const TierTransition({
    required this.from,
    required this.to,
    required this.timestamp,
  });

  final HealthTier from;
  final HealthTier to;
  final DateTime timestamp;

  /// True if the network got worse (higher tier index = worse).
  bool get isWorsening => to.index > from.index;

  /// True if the network is recovering.
  bool get isImproving => to.index < from.index;
}

/// Watches [networkHealthProvider] and detects catastrophe tier transitions.
///
/// When the tier worsens, a [CatastropheEvent] is created. When it reaches
/// fracture (Tier 3), a [RepairMission] auto-generates targeting the concepts
/// with the worst freshness in the affected cluster.
final catastropheProvider =
    NotifierProvider<CatastropheNotifier, CatastropheState>(
      CatastropheNotifier.new,
    );

class CatastropheNotifier extends Notifier<CatastropheState> {
  @override
  CatastropheState build() {
    // Seed previousTier from current health to avoid phantom events on cold start.
    final currentHealth = ref.read(networkHealthProvider);
    final initialTier = currentHealth.tier;

    // Watch health and react to subsequent changes.
    ref.listen(networkHealthProvider, (previous, next) {
      _onHealthChanged(previous, next);
    });

    return CatastropheState(previousTier: initialTier);
  }

  void _onHealthChanged(NetworkHealth? previous, NetworkHealth next) {
    final prevTier = previous?.tier ?? state.previousTier;
    final nextTier = next.tier;

    if (prevTier == nextTier) {
      // Same tier — no transition, just update previous.
      state = state.copyWith(previousTier: nextTier);
      return;
    }

    final transition = TierTransition(
      from: prevTier,
      to: nextTier,
      timestamp: ref.read(clockProvider)(),
    );

    if (transition.isWorsening) {
      _onWorseningTransition(transition, next);
    } else {
      _onImprovingTransition(transition);
    }
  }

  void _onWorseningTransition(TierTransition transition, NetworkHealth health) {
    final now = ref.read(clockProvider)();

    // Find the worst cluster (for labeling the event)
    String? worstCluster;
    if (health.clusterHealth.isNotEmpty) {
      worstCluster =
          health.clusterHealth.entries
              .reduce((a, b) => a.value < b.value ? a : b)
              .key;
    }

    // Create catastrophe event
    final event = CatastropheEvent(
      id: 'catastrophe_${_uuid.v4()}',
      tier: transition.to,
      affectedConceptIds: _findAtRiskConceptIds(),
      createdAt: now,
      clusterLabel: worstCluster,
    );

    final updatedEvents = state.activeEvents.add(event);

    // Auto-generate repair mission on fracture or collapse
    var updatedMissions = state.activeMissions;
    if (transition.to == HealthTier.fracture ||
        transition.to == HealthTier.collapse) {
      final missionConcepts = _findRepairTargets();
      if (missionConcepts.isNotEmpty) {
        final mission = RepairMission(
          id: 'mission_${_uuid.v4()}',
          conceptIds: missionConcepts,
          createdAt: now,
          catastropheEventId: event.id,
        );
        updatedMissions = updatedMissions.add(mission);
      }
    }

    state = state.copyWith(
      previousTier: transition.to,
      activeEvents: updatedEvents,
      activeMissions: updatedMissions,
      latestTransition: transition,
    );
  }

  void _onImprovingTransition(TierTransition transition) {
    // Resolve events whose tier is now above the current tier
    final resolvedEvents = state.activeEvents.map((event) {
      if (!event.isResolved && event.tier.index > transition.to.index) {
        return event.withResolved(ref.read(clockProvider)());
      }
      return event;
    });

    // Keep only unresolved events in the active list
    final stillActive = resolvedEvents.where((e) => !e.isResolved).toIList();

    state = state.copyWith(
      previousTier: transition.to,
      activeEvents: stillActive,
      latestTransition: transition,
    );
  }

  /// Record that a concept was reviewed during a repair mission.
  void recordMissionReview(String conceptId) {
    final now = ref.read(clockProvider)();
    final updatedMissions = state.activeMissions.map((mission) {
      if (mission.isComplete) return mission;
      if (!mission.conceptIds.contains(conceptId)) return mission;
      return mission.withReviewedConcept(conceptId, now: now);
    });

    // Remove completed missions from active list
    final stillActive = updatedMissions.where((m) => !m.isComplete).toIList();

    state = state.copyWith(activeMissions: stillActive);
  }

  /// Find concept IDs that are at risk (fading, due, or locked with
  /// high out-degree dependents).
  List<String> _findAtRiskConceptIds() {
    final graph = ref.read(knowledgeGraphProvider).valueOrNull;
    if (graph == null) return [];

    final clusters = ref.read(clusterProvider);
    final health = ref.read(networkHealthProvider);

    // Find concepts in the weakest clusters
    final weakClusterLabels =
        health.clusterHealth.entries
            .where((e) => e.value < 0.5)
            .map((e) => e.key)
            .toSet();

    final atRisk = <String>[];
    for (final cluster in clusters) {
      if (weakClusterLabels.contains(cluster.label)) {
        atRisk.addAll(cluster.conceptIds);
      }
    }

    return atRisk;
  }

  /// Find the best concepts to target for a repair mission.
  /// Prioritizes concepts in the weakest clusters.
  List<String> _findRepairTargets() {
    final graph = ref.read(knowledgeGraphProvider).valueOrNull;
    if (graph == null) return [];

    final clusters = ref.read(clusterProvider);
    final health = ref.read(networkHealthProvider);

    // Target the weakest cluster's concepts
    if (health.clusterHealth.isEmpty) {
      // No clusters — target all concepts
      return graph.concepts.map((c) => c.id).toList();
    }

    final weakest = health.clusterHealth.entries.reduce(
      (a, b) => a.value < b.value ? a : b,
    );

    final targetCluster =
        clusters.where((c) => c.label == weakest.key).firstOrNull;

    return targetCluster?.conceptIds.toList() ?? [];
  }
}
