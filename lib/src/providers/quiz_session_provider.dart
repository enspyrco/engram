import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/fsrs_engine.dart';
import '../engine/review_rating.dart';
import '../engine/scheduler.dart';
import '../engine/sm2.dart';
import '../engine/streak.dart';
import '../models/quiz_item.dart';
import '../models/quiz_session_state.dart';
import '../models/session_mode.dart';
import 'auth_provider.dart';
import 'catastrophe_provider.dart';
import 'desired_retention_provider.dart';
import 'clock_provider.dart';
import 'guardian_provider.dart';
import 'knowledge_graph_provider.dart';
import 'relay_provider.dart';
import 'settings_provider.dart';

final quizSessionProvider =
    NotifierProvider<QuizSessionNotifier, QuizSessionState>(
      QuizSessionNotifier.new,
    );

class QuizSessionNotifier extends Notifier<QuizSessionState> {
  @override
  QuizSessionState build() => QuizSessionState();

  void startSession({
    SessionMode mode = SessionMode.full,
    String? collectionId,
    String? topicId,
  }) {
    final graph = ref.read(knowledgeGraphProvider).valueOrNull;
    if (graph == null) return;

    final repo = ref.read(settingsRepositoryProvider);
    final absence = inspectAbsence(
      lastSessionDateIso: repo.getLastSessionDate(),
      now: ref.read(clockProvider)(),
    );

    final isComeback = absence?.isComeback ?? false;

    // Comeback overrides mode to a gentle re-entry
    final effectiveMode = isComeback ? SessionMode.quick : mode;
    final maxItems = effectiveMode.maxItems;

    // Resolve topic to document IDs for filtering
    Set<String>? topicDocumentIds;
    if (topicId != null) {
      final topic = graph.topics.where((t) => t.id == topicId).firstOrNull;
      if (topic != null) {
        topicDocumentIds = topic.documentIds.unlock;
      }
    }

    final dueItems = scheduleDueItems(
      graph,
      maxItems: maxItems,
      collectionId: collectionId,
      topicDocumentIds: topicDocumentIds,
    );
    if (dueItems.isEmpty) {
      state = QuizSessionState(
        phase: QuizPhase.summary,
        isComeback: isComeback,
        sessionMode: effectiveMode,
        daysSinceLastSession: absence?.daysSinceLastSession,
      );
      return;
    }

    state = QuizSessionState(
      phase: QuizPhase.question,
      items: dueItems,
      isComeback: isComeback,
      sessionMode: effectiveMode,
      daysSinceLastSession: absence?.daysSinceLastSession,
    );
  }

  void revealAnswer() {
    if (state.phase != QuizPhase.question) return;
    state = state.copyWith(phase: QuizPhase.revealed);
  }

  /// Rate the current quiz item using either SM-2 or FSRS.
  ///
  /// Dispatches based on the [ReviewRating] subclass:
  /// - [Sm2Rating] → classic SM-2 algorithm
  /// - [FsrsReviewRating] → FSRS algorithm with desired retention
  Future<void> rateItem(ReviewRating rating) async {
    if (state.phase != QuizPhase.revealed) return;

    final item = state.currentItem;
    if (item == null) return;

    // Check if this concept is in an active repair mission for 1.5x bonus
    final activeMissions = ref.read(catastropheProvider).activeMissions;
    final inMission = activeMissions.any(
      (m) => m.conceptIds.contains(item.conceptId),
    );

    final now = ref.read(clockProvider)();
    final QuizItem updated;
    final int ratingValue;

    switch (rating) {
      case Sm2Rating(:final quality):
        final result = sm2(
          quality: quality,
          easeFactor: item.easeFactor,
          interval: item.interval,
          repetitions: item.repetitions,
        );
        final effectiveInterval =
            inMission ? (result.interval * 1.5).round() : result.interval;
        final nextReview = now.add(Duration(days: effectiveInterval));
        updated = item.withReview(
          easeFactor: result.easeFactor,
          interval: effectiveInterval,
          repetitions: result.repetitions,
          nextReview: nextReview,
          now: now,
        );
        ratingValue = quality;

      case FsrsReviewRating(:final rating):
        final retentionMap = ref.read(desiredRetentionProvider);
        final desiredRetention = retentionMap[item.conceptId] ?? 0.9;
        final result = reviewFsrs(
          rating: rating,
          difficulty: item.difficulty!,
          stability: item.stability!,
          fsrsState: item.fsrsState!,
          lapses: item.lapses ?? 0,
          lastReview: item.lastReview ?? now,
          now: now,
          desiredRetention: desiredRetention,
        );
        final effectiveInterval =
            inMission ? (result.intervalDays * 1.5).round() : result.intervalDays;
        final nextReview = now.add(Duration(days: effectiveInterval));
        updated = item.withFsrsReview(
          difficulty: result.difficulty,
          stability: result.stability,
          fsrsState: result.fsrsState,
          lapses: result.lapses,
          interval: effectiveInterval,
          nextReview: nextReview,
          now: now,
        );
        // Map FSRS ratings to int for the ratings list:
        // again→1, hard→3, good→4, easy→5
        ratingValue = switch (rating) {
          FsrsRating.again => 1,
          FsrsRating.hard => 3,
          FsrsRating.good => 4,
          FsrsRating.easy => 5,
        };
    }

    // Advance the session state first — the UI must never block on I/O.
    final newRatings = state.ratings.add(ratingValue);
    final nextIndex = state.currentIndex + 1;

    if (nextIndex >= state.items.length) {
      state = state.copyWith(
        phase: QuizPhase.summary,
        currentIndex: nextIndex,
        ratings: newRatings,
      );
      // Persist streak after UI update
      unawaited(_persistStreak());
    } else {
      state = state.copyWith(
        phase: QuizPhase.question,
        currentIndex: nextIndex,
        ratings: newRatings,
      );
    }

    // Persist the review (fire-and-forget — in-memory graph state is
    // updated first inside updateQuizItem).
    unawaited(
      ref.read(knowledgeGraphProvider.notifier).updateQuizItem(updated),
    );

    // Record mission progress and award glory points.
    if (inMission) {
      ref
          .read(catastropheProvider.notifier)
          .recordMissionReview(item.conceptId);
      final teamRepo = ref.read(teamRepositoryProvider);
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (teamRepo != null && uid != null) {
        unawaited(teamRepo.addGloryPoints(uid, missionPoints: 1));
      }
    }

    // Check relay leg completion.
    _checkRelayLegCompletion(item.conceptId, updated);
  }

  Future<void> _persistStreak() async {
    final repo = ref.read(settingsRepositoryProvider);
    final update = computeStreakAfterSession(
      lastSessionDateIso: repo.getLastSessionDate(),
      previousStreak: repo.getCurrentStreak(),
      previousLongest: repo.getLongestStreak(),
      now: ref.read(clockProvider)(),
    );
    await Future.wait([
      repo.setLastSessionDate(update.lastSessionDate),
      repo.setCurrentStreak(update.currentStreak),
      repo.setLongestStreak(update.longestStreak),
    ]);
  }

  /// Check if a reviewed concept completes a relay leg.
  ///
  /// Early-exits in O(1) when the concept isn't in any active relay,
  /// which is the common case for 95%+ of quiz answers.
  void _checkRelayLegCompletion(String conceptId, QuizItem updatedItem) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final relays = ref.read(relayProvider).valueOrNull ?? [];
    if (relays.isEmpty) return;

    // O(1) check: is this concept even in an active relay leg?
    final hasMatch = relays.any(
      (r) => r.legs.any((l) => l.conceptId == conceptId),
    );
    if (!hasMatch) return;

    final graph = ref.read(knowledgeGraphProvider).valueOrNull;
    if (graph == null) return;

    for (final relay in relays) {
      for (var i = 0; i < relay.legs.length; i++) {
        final leg = relay.legs[i];
        if (leg.conceptId != conceptId) continue;
        if (leg.claimedByUid != uid) continue;
        if (leg.completedAt != null) continue;

        // Check if ALL quiz items for this concept are mastered
        final conceptItems = graph.quizItems.where(
          (q) => q.conceptId == conceptId,
        );
        final allMastered = conceptItems.every((q) {
          // Use the updated item if this is the one we just reviewed
          final item = q.id == updatedItem.id ? updatedItem : q;
          return item.isMasteredForUnlock;
        });

        if (allMastered) {
          unawaited(ref.read(relayProvider.notifier).completeLeg(relay.id, i));
        }
      }
    }
  }

  void reset() {
    state = QuizSessionState();
  }
}
