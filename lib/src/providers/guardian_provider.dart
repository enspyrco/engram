import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../models/concept_cluster.dart';
import '../storage/team_repository.dart';
import 'auth_provider.dart';
import 'friends_provider.dart';
import 'network_health_provider.dart';
import 'settings_provider.dart';

/// Provides the [TeamRepository] for the current user's wiki group.
final teamRepositoryProvider = Provider<TeamRepository?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final config = ref.watch(settingsProvider);
  if (config.outlineApiUrl.isEmpty) return null;

  final wikiHash = hashWikiUrl(config.outlineApiUrl);
  return TeamRepository(
    firestore: ref.watch(firestoreProvider),
    wikiUrlHash: wikiHash,
  );
});

/// Guardian system state: cluster assignments and the current user's role.
@immutable
class GuardianState {
  const GuardianState({
    this.clusters = const [],
    this.currentUid,
  });

  final List<ConceptCluster> clusters;
  final String? currentUid;

  /// Clusters guarded by the current user.
  List<ConceptCluster> get myGuardedClusters =>
      clusters.where((c) => c.guardianUid == currentUid).toList();

  /// Look up the guardian UID for a specific cluster label.
  String? guardianForCluster(String label) =>
      clusters.where((c) => c.label == label).firstOrNull?.guardianUid;

  GuardianState copyWith({
    List<ConceptCluster>? clusters,
    String? currentUid,
  }) {
    return GuardianState(
      clusters: clusters ?? this.clusters,
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
      return const GuardianState();
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
