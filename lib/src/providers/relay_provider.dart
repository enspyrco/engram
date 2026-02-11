import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nudge.dart';
import '../models/relay_challenge.dart';
import 'auth_provider.dart';
import 'guardian_provider.dart';
import 'nudge_provider.dart';
import 'user_profile_provider.dart';

/// Manages relay challenges — streams active relays from Firestore and
/// provides claim/complete/create operations.
final relayProvider =
    AsyncNotifierProvider<RelayNotifier, List<RelayChallenge>>(
  RelayNotifier.new,
);

class RelayNotifier extends AsyncNotifier<List<RelayChallenge>> {
  @override
  Future<List<RelayChallenge>> build() async {
    final teamRepo = ref.watch(teamRepositoryProvider);
    if (teamRepo == null) return [];

    final subscription = teamRepo.watchActiveRelays().listen((relays) {
      state = AsyncData(relays);
      _checkForStalls(relays);
    });
    ref.onDispose(subscription.cancel);

    return await teamRepo.watchActiveRelays().first;
  }

  /// Create a new relay challenge with a chain of concepts.
  Future<void> createRelay({
    required String title,
    required List<RelayLeg> legs,
  }) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (teamRepo == null || user == null) return;

    final now = DateTime.now().toUtc();
    final relay = RelayChallenge(
      id: 'relay_${now.millisecondsSinceEpoch}',
      title: title,
      legs: legs,
      createdAt: now.toIso8601String(),
      createdByUid: user.uid,
    );

    await teamRepo.writeRelay(relay);
  }

  /// Claim a leg in a relay challenge.
  Future<void> claimLeg(String relayId, int legIndex) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (teamRepo == null || user == null) return;

    final relays = state.valueOrNull ?? [];
    final relay = relays.where((r) => r.id == relayId).firstOrNull;
    if (relay == null) return;

    // Validate: leg must be unclaimed
    if (relay.legs[legIndex].status != RelayLegStatus.unclaimed) return;

    // Validate: prior leg must be completed (or this is the first leg)
    if (legIndex > 0 &&
        relay.legs[legIndex - 1].completedAt == null) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = relay.withLegClaimed(
      legIndex,
      uid: user.uid,
      displayName: profile?.displayName ?? 'Someone',
      timestamp: now,
    );

    await teamRepo.updateRelay(updated);
  }

  /// Complete a leg in a relay challenge. Awards glory points.
  Future<void> completeLeg(String relayId, int legIndex) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (teamRepo == null || user == null) return;

    final relays = state.valueOrNull ?? [];
    final relay = relays.where((r) => r.id == relayId).firstOrNull;
    if (relay == null) return;

    final leg = relay.legs[legIndex];
    if (leg.completedAt != null) return; // already completed

    final now = DateTime.now().toUtc().toIso8601String();
    var updated = relay.withLegCompleted(legIndex, now);

    // Determine glory points
    var points = 3; // base per leg

    // Rescue bonus: completing a stalled leg
    if (leg.status == RelayLegStatus.stalled) {
      points = 4;
    }

    // Check if this was the final leg
    final isLastLeg = updated.completedLegs == updated.legs.length;
    if (isLastLeg) {
      updated = updated.withCompleted(now);
      points += 5; // bonus for completing the relay
    }

    await teamRepo.updateRelay(updated);
    unawaited(teamRepo.addGloryPoints(user.uid, relayPoints: points));
  }

  /// Check for stalled legs and auto-send nudges with 6h debounce.
  void _checkForStalls(List<RelayChallenge> relays) {
    final now = DateTime.now().toUtc();

    for (final relay in relays) {
      for (var i = 0; i < relay.legs.length; i++) {
        final leg = relay.legs[i];
        if (!leg.isOverdueAt(now)) continue;
        if (leg.claimedByUid == null) continue;

        // Debounce: only nudge if >6h since last nudge
        if (leg.lastStallNudgeAt != null) {
          final lastNudge = DateTime.parse(leg.lastStallNudgeAt!);
          if (now.difference(lastNudge).inHours < 6) continue;
        }

        _sendStallNudge(relay, i, now);
      }
    }
  }

  void _sendStallNudge(RelayChallenge relay, int legIndex, DateTime now) {
    final leg = relay.legs[legIndex];
    final user = ref.read(authStateProvider).valueOrNull;
    final teamRepo = ref.read(teamRepositoryProvider);
    if (user == null || teamRepo == null) return;

    // Send nudge to the person who claimed the stalled leg.
    // Use recipient UID in the nudge ID for idempotency — if multiple clients
    // trigger the stall check, they produce the same document ID.
    final nudge = Nudge(
      id: 'stall_${relay.id}_$legIndex',
      fromUid: 'system',
      fromName: 'Relay System',
      toUid: leg.claimedByUid!,
      conceptName: leg.conceptName,
      message: 'Your relay leg "${leg.conceptName}" in "${relay.title}" '
          'is overdue! Master it or let someone else take over.',
      createdAt: now.toIso8601String(),
    );

    unawaited(ref.read(nudgeProvider.notifier).sendNudge(nudge));

    // Update the leg's lastStallNudgeAt
    final updated = relay.withLegStallNudge(legIndex, now.toIso8601String());
    unawaited(teamRepo.updateRelay(updated));
  }
}
