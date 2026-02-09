import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/scheduler.dart';
import '../engine/sm2.dart';
import '../engine/streak.dart';
import '../models/quiz_session_state.dart';
import '../models/session_mode.dart';
import 'knowledge_graph_provider.dart';
import 'settings_provider.dart';

final quizSessionProvider =
    NotifierProvider<QuizSessionNotifier, QuizSessionState>(
  QuizSessionNotifier.new,
);

class QuizSessionNotifier extends Notifier<QuizSessionState> {
  @override
  QuizSessionState build() => const QuizSessionState();

  void startSession({SessionMode mode = SessionMode.full}) {
    final graph = ref.read(knowledgeGraphProvider).valueOrNull;
    if (graph == null) return;

    final repo = ref.read(settingsRepositoryProvider);
    final absence = inspectAbsence(
      lastSessionDateIso: repo.getLastSessionDate(),
      now: DateTime.now().toUtc(),
    );

    final isComeback = absence?.isComeback ?? false;

    // Comeback overrides mode to a gentle re-entry
    final effectiveMode = isComeback ? SessionMode.quick : mode;
    final maxItems = effectiveMode.maxItems;

    final dueItems = scheduleDueItems(graph, maxItems: maxItems);
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

  Future<void> rateItem(int quality) async {
    if (state.phase != QuizPhase.revealed) return;

    final item = state.currentItem;
    if (item == null) return;

    final result = sm2(
      quality: quality,
      easeFactor: item.easeFactor,
      interval: item.interval,
      repetitions: item.repetitions,
    );

    final nextReview = DateTime.now()
        .toUtc()
        .add(Duration(days: result.interval))
        .toIso8601String();

    final updated = item.withReview(
      easeFactor: result.easeFactor,
      interval: result.interval,
      repetitions: result.repetitions,
      nextReview: nextReview,
    );

    await ref.read(knowledgeGraphProvider.notifier).updateQuizItem(updated);

    final newRatings = [...state.ratings, quality];
    final nextIndex = state.currentIndex + 1;

    if (nextIndex >= state.items.length) {
      // Session complete — persist streak
      await _persistStreak();

      state = state.copyWith(
        phase: QuizPhase.summary,
        currentIndex: nextIndex,
        ratings: newRatings,
      );
    } else {
      state = state.copyWith(
        phase: QuizPhase.question,
        currentIndex: nextIndex,
        ratings: newRatings,
      );
    }
  }

  Future<void> _persistStreak() async {
    final repo = ref.read(settingsRepositoryProvider);
    final update = computeStreakAfterSession(
      lastSessionDateIso: repo.getLastSessionDate(),
      previousStreak: repo.getCurrentStreak(),
      previousLongest: repo.getLongestStreak(),
      now: DateTime.now().toUtc(),
    );
    await Future.wait([
      repo.setLastSessionDate(update.lastSessionDate),
      repo.setCurrentStreak(update.currentStreak),
      repo.setLongestStreak(update.longestStreak),
    ]);
  }

  void reset() {
    state = const QuizSessionState();
  }
}
