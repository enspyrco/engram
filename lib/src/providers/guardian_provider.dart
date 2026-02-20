import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../models/concept_cluster.dart';
import '../storage/team_repository.dart';
import 'auth_provider.dart';
import 'network_health_provider.dart';
import 'wiki_group_membership_provider.dart';

/// Provides the [TeamRepository] for the current user's wiki group.
///
/// Depends on [wikiGroupMembershipProvider] to ensure the user has joined
/// the wiki group before any Firestore listeners start. Returns `null`
/// until membership is confirmed.
final teamRepositoryProvider = Provider<TeamRepository?>((ref) {
  final wikiHash = ref.watch(wikiGroupMembershipProvider).valueOrNull;
  if (wikiHash == null) return null;

  return TeamRepository(
    firestore: ref.watch(firestoreProvider),
    wikiUrlHash: wikiHash,
  );
});

/// Guardian system state: cluster assignments and the current user's role.
@immutable
class GuardianState {
  GuardianState({
    List<ConceptCluster> clusters = const [],
    this.currentUid,
  }) : clusters = IList(clusters);

  const GuardianState._raw({
    required this.clusters,
    this.currentUid,
  });

  final IList<ConceptCluster> clusters;
  final String? currentUid;

  /// Clusters guarded by the current user.
  Iterable<ConceptCluster> get myGuardedClusters =>
      clusters.where((c) => c.guardianUid == currentUid);

  /// Look up the guardian UID for a specific cluster label.
  String? guardianForCluster(String label) =>
      clusters.where((c) => c.label == label).firstOrNull?.guardianUid;

  GuardianState copyWith({
    List<ConceptCluster>? clusters,
    String? currentUid,
  }) {
    return GuardianState._raw(
      clusters: clusters != null ? IList(clusters) : this.clusters,
      currentUid: currentUid ?? this.currentUid,
    );
  }
}

/// Manages guardian assignments for concept clusters.
///
/// Watches clusters from Firestore via [TeamRepository] and provides
/// volunteer/resign operations. Awards guardian points when a guarded
/// cluster stays above 80% health.
final guardianProvider =
    NotifierProvider<GuardianNotifier, GuardianState>(GuardianNotifier.new);

class GuardianNotifier extends Notifier<GuardianState> {
  @override
  GuardianState build() {
    final user = ref.watch(authStateProvider).valueOrNull;
    final teamRepo = ref.watch(teamRepositoryProvider);

    if (user == null || teamRepo == null) {
      return GuardianState();
    }

    // Stream clusters from Firestore
    final subscription = teamRepo.watchClusters().listen((clusters) {
      state = state.copyWith(clusters: clusters);
      _checkGuardianPoints(clusters);
    });
    ref.onDispose(subscription.cancel);

    return GuardianState(currentUid: user.uid);
  }

  /// Volunteer as guardian for a cluster.
  Future<void> volunteerAsGuardian(String clusterDocId) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (teamRepo == null || user == null) return;

    await teamRepo.setClusterGuardian(clusterDocId, user.uid);
  }

  /// Resign guardianship of a cluster.
  Future<void> resignGuardian(String clusterDocId) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    if (teamRepo == null) return;

    await teamRepo.setClusterGuardian(clusterDocId, null);
  }

  /// Award guardian points when guarded clusters are above 80% health.
  void _checkGuardianPoints(List<ConceptCluster> clusters) {
    final uid = state.currentUid;
    if (uid == null) return;

    final health = ref.read(networkHealthProvider);
    final teamRepo = ref.read(teamRepositoryProvider);
    if (teamRepo == null) return;

    final myGuarded = clusters.where((c) => c.guardianUid == uid);
    var earned = 0;

    for (final cluster in myGuarded) {
      final clusterHealth = health.clusterHealth[cluster.label] ?? 0.0;
      if (clusterHealth >= 0.8) {
        earned += 1;
      }
    }

    if (earned > 0) {
      teamRepo.addGloryPoints(uid, guardianPoints: earned);
    }
  }
}
