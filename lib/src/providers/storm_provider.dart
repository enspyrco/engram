import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/entropy_storm.dart';
import 'auth_provider.dart';
import 'guardian_provider.dart';
import 'network_health_provider.dart';

const _uuid = Uuid();

/// Manages the current entropy storm — streams from Firestore and handles
/// opt-in/out, status transitions, and health tracking.
final stormProvider =
    AsyncNotifierProvider<StormNotifier, EntropyStorm?>(StormNotifier.new);

class StormNotifier extends AsyncNotifier<EntropyStorm?> {
  @override
  Future<EntropyStorm?> build() async {
    final teamRepo = ref.watch(teamRepositoryProvider);
    if (teamRepo == null) return null;

    final subscription = teamRepo.watchActiveStorm().listen((storm) {
      state = AsyncData(storm);
      if (storm != null) _checkStormTransitions(storm);
    });
    ref.onDispose(subscription.cancel);

    // Track health during active storm
    ref.listen(networkHealthProvider, (previous, next) {
      final storm = state.valueOrNull;
      if (storm == null || !storm.isActive) return;
      _trackHealth(storm, next.score);
    });

    return await teamRepo.watchActiveStorm().first;
  }

  /// Schedule a new entropy storm.
  Future<void> scheduleStorm(DateTime startTime) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (teamRepo == null || user == null) return;

    final end = startTime.add(const Duration(hours: 48));
    final storm = EntropyStorm(
      id: 'storm_${_uuid.v4()}',
      scheduledStart: startTime.toUtc().toIso8601String(),
      scheduledEnd: end.toUtc().toIso8601String(),
      status: StormStatus.scheduled,
      participantUids: [user.uid], // creator auto-opts-in
      createdByUid: user.uid,
    );

    await teamRepo.writeStorm(storm);
  }

  /// Opt in to the current storm.
  Future<void> optIn() async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    final storm = state.valueOrNull;
    if (teamRepo == null || user == null || storm == null) return;
    if (storm.status != StormStatus.scheduled) return;

    final updated = storm.withParticipant(user.uid);
    await teamRepo.updateStorm(updated);
  }

  /// Opt out of the current storm.
  Future<void> optOut() async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    final storm = state.valueOrNull;
    if (teamRepo == null || user == null || storm == null) return;
    if (storm.status != StormStatus.scheduled) return;

    final updated = storm.withoutParticipant(user.uid);
    await teamRepo.updateStorm(updated);
  }

  /// Check if storm should transition between scheduled → active → survived/failed.
  void _checkStormTransitions(EntropyStorm storm) {
    final now = DateTime.now().toUtc();
    final teamRepo = ref.read(teamRepositoryProvider);
    if (teamRepo == null) return;

    if (storm.status == StormStatus.scheduled) {
      final start = DateTime.parse(storm.scheduledStart);
      if (now.isAfter(start)) {
        // Transition to active
        unawaited(teamRepo.updateStorm(storm.withStatus(StormStatus.active)));
      }
    } else if (storm.status == StormStatus.active) {
      final end = DateTime.parse(storm.scheduledEnd);
      if (now.isAfter(end)) {
        _resolveStorm(storm);
      }
    }
  }

  /// Track lowest health during active storm.
  void _trackHealth(EntropyStorm storm, double currentHealth) {
    final teamRepo = ref.read(teamRepositoryProvider);
    if (teamRepo == null) return;

    if (storm.lowestHealth == null || currentHealth < storm.lowestHealth!) {
      unawaited(teamRepo.updateStorm(storm.withLowestHealth(currentHealth)));
    }
  }

  /// Resolve a storm: survived if health stayed above threshold, failed otherwise.
  void _resolveStorm(EntropyStorm storm) {
    final teamRepo = ref.read(teamRepositoryProvider);
    if (teamRepo == null) return;

    final survived = storm.lowestHealth != null &&
        storm.lowestHealth! >= storm.healthThreshold;

    final finalStatus =
        survived ? StormStatus.survived : StormStatus.failed;
    unawaited(teamRepo.updateStorm(storm.withStatus(finalStatus)));

    // Award storm points to all participants if survived
    if (survived) {
      for (final uid in storm.participantUids) {
        unawaited(teamRepo.addGloryPoints(uid, stormPoints: 10));
      }
    }
  }
}

/// Whether an entropy storm is currently active.
final isStormActiveProvider = Provider<bool>((ref) {
  final stormAsync = ref.watch(stormProvider);
  final storm = stormAsync.valueOrNull;
  if (storm == null) return false;
  return storm.isActive;
});

/// Freshness decay multiplier: 2.0 during active storms, 1.0 otherwise.
final freshnessDecayMultiplierProvider = Provider<double>((ref) {
  return ref.watch(isStormActiveProvider) ? 2.0 : 1.0;
});
