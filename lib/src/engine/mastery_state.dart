import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
import 'fsrs_engine.dart';
import 'graph_analyzer.dart';

/// Mastery state for a concept node, determines its color.
enum MasteryState { locked, due, learning, mastered, fading }

/// Number of days after which a mastered concept starts fading.
const fadingThresholdDays = 30;

/// Maximum days used for freshness linear decay (maps to 0.3 freshness).
const maxDecayDays = 60;

/// Color for each mastery state.
const masteryColors = {
  MasteryState.locked: Colors.grey,
  MasteryState.due: Colors.red,
  MasteryState.learning: Colors.amber,
  MasteryState.mastered: Colors.green,
  MasteryState.fading: Color(0xFF81C784),
};

/// Determines the mastery state of a single concept.
///
/// Uses FSRS retrievability when any quiz item for the concept has FSRS state.
/// Falls back to SM-2 interval-based heuristics for legacy cards.
MasteryState masteryStateOf(
  String conceptId,
  KnowledgeGraph graph,
  GraphAnalyzer analyzer, {
  DateTime? now,
}) {
  if (!analyzer.isConceptUnlocked(conceptId)) return MasteryState.locked;

  final items = graph.quizItems.where((q) => q.conceptId == conceptId);
  if (items.isEmpty) return MasteryState.mastered;

  // Use FSRS path if any item has FSRS state (during transition, FSRS items
  // are the newer, more accurate signal).
  if (items.any((q) => q.isFsrs)) {
    return _fsrsMasteryState(items, now: now);
  }

  return _sm2MasteryState(items, now: now);
}

/// SM-2 mastery state: interval-based heuristics.
MasteryState _sm2MasteryState(Iterable<QuizItem> items, {DateTime? now}) {
  final allReviewed = items.every((q) => q.repetitions >= 1);
  if (!allReviewed) return MasteryState.due;

  final allMastered = items.every((q) => q.interval >= 21);
  if (!allMastered) return MasteryState.learning;

  // Mastered — check for fading
  final oldest = _oldestLastReview(items);
  if (oldest != null) {
    final currentTime = now ?? DateTime.now().toUtc();
    final daysSince = currentTime.difference(oldest).inDays;
    if (daysSince > fadingThresholdDays) return MasteryState.fading;
  }

  return MasteryState.mastered;
}

/// FSRS mastery state: retrievability-based.
///
/// Computes the average retrievability across all FSRS items for a concept.
/// - R < 0.5  → due (recall probability too low)
/// - R 0.5–0.85 → learning (making progress)
/// - R >= 0.85 → mastered (with fading check on lastReview)
MasteryState _fsrsMasteryState(Iterable<QuizItem> items, {DateTime? now}) {
  final currentTime = now ?? DateTime.now().toUtc();

  // Check if any items have never been reviewed.
  final anyUnreviewed = items.any((q) => q.lastReview == null);
  if (anyUnreviewed) return MasteryState.due;

  // Average retrievability across FSRS items (skip non-FSRS in mixed sets).
  final fsrsItems = items.where((q) => q.isFsrs);
  if (fsrsItems.isEmpty) return MasteryState.due;

  var totalR = 0.0;
  for (final item in fsrsItems) {
    totalR += fsrsRetrievability(
      stability: item.stability!,
      fsrsState: item.fsrsState!,
      lastReview: item.lastReview!,
      now: currentTime,
    );
  }
  final avgR = totalR / fsrsItems.length;

  if (avgR < 0.5) return MasteryState.due;
  if (avgR < 0.85) return MasteryState.learning;

  // Mastered — check for fading
  final oldest = _oldestLastReview(items);
  if (oldest != null) {
    final daysSince = currentTime.difference(oldest).inDays;
    if (daysSince > fadingThresholdDays) return MasteryState.fading;
  }

  return MasteryState.mastered;
}

/// Compute freshness of a concept (1.0 = just reviewed, 0.0+ = long ago).
///
/// FSRS items use retrievability directly as freshness (0.0–1.0), which is
/// more principled than linear time decay. SM-2 items keep the linear decay
/// from 1.0 to 0.3 over [maxDecayDays].
///
/// The optional [decayMultiplier] accelerates decay for SM-2 items (e.g. 2.0
/// during entropy storms) without modifying intervals — only the freshness
/// *display* changes. FSRS items are unaffected by [decayMultiplier] since
/// their freshness comes from the forgetting curve.
double freshnessOf(
  String conceptId,
  KnowledgeGraph graph, {
  DateTime? now,
  double decayMultiplier = 1.0,
}) {
  final items = graph.quizItems.where((q) => q.conceptId == conceptId);

  // Use FSRS retrievability for concepts with FSRS items.
  final fsrsItems = items.where((q) => q.isFsrs && q.lastReview != null);
  if (fsrsItems.isNotEmpty) {
    final currentTime = now ?? DateTime.now().toUtc();
    var totalR = 0.0;
    for (final item in fsrsItems) {
      totalR += fsrsRetrievability(
        stability: item.stability!,
        fsrsState: item.fsrsState!,
        lastReview: item.lastReview!,
        now: currentTime,
      );
    }
    return totalR / fsrsItems.length;
  }

  // SM-2 fallback: linear decay.
  final oldest = _oldestLastReview(items);
  if (oldest == null) return 1.0;

  final currentTime = now ?? DateTime.now().toUtc();
  final daysSince = currentTime.difference(oldest).inDays;
  if (daysSince <= 0) return 1.0;

  // Linear decay from 1.0 to 0.3 over maxDecayDays
  final effectiveDays = daysSince * decayMultiplier;
  final t = math.min(effectiveDays / maxDecayDays, 1.0);
  return 1.0 - (0.7 * t);
}

/// Find the oldest `lastReview` timestamp across a set of quiz items.
DateTime? _oldestLastReview(Iterable<QuizItem> items) {
  DateTime? oldest;
  for (final item in items) {
    if (item.lastReview == null) continue;
    final date = item.lastReview!;
    if (oldest == null || date.isBefore(oldest)) {
      oldest = date;
    }
  }
  return oldest;
}
