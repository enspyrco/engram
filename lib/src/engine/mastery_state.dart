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

/// FSRS retrievability below which a concept is considered due for review.
const fsrsDueThreshold = 0.5;

/// FSRS retrievability at or above which a concept is considered mastered.
const fsrsMasteredThreshold = 0.85;

/// Color for each mastery state.
const masteryColors = {
  MasteryState.locked: Colors.grey,
  MasteryState.due: Colors.red,
  MasteryState.learning: Colors.amber,
  MasteryState.mastered: Colors.green,
  MasteryState.fading: Color(0xFF81C784),
};

/// Determines the mastery state of a single concept using FSRS retrievability.
///
/// Computes the average retrievability across all quiz items for a concept.
/// - R < [fsrsDueThreshold]  → due (recall probability too low)
/// - R [fsrsDueThreshold]–[fsrsMasteredThreshold] → learning (making progress)
/// - R >= [fsrsMasteredThreshold] → mastered (with fading check on lastReview)
MasteryState masteryStateOf(
  String conceptId,
  KnowledgeGraph graph,
  GraphAnalyzer analyzer, {
  DateTime? now,
}) {
  if (!analyzer.isConceptUnlocked(conceptId)) return MasteryState.locked;

  final items = graph.quizItems.where((q) => q.conceptId == conceptId);
  if (items.isEmpty) return MasteryState.mastered;

  final currentTime = now ?? DateTime.now().toUtc();

  // All cards are FSRS after Phase 3 migration; check for unreviewed items.
  final anyUnreviewed = items.any((q) => q.lastReview == null);
  if (anyUnreviewed) return MasteryState.due;

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

  if (avgR < fsrsDueThreshold) return MasteryState.due;
  if (avgR < fsrsMasteredThreshold) return MasteryState.learning;

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
/// Uses FSRS retrievability directly as freshness (0.0–1.0), which is more
/// principled than time-based linear decay. Returns 1.0 for concepts with
/// no reviewed items.
double freshnessOf(
  String conceptId,
  KnowledgeGraph graph, {
  DateTime? now,
}) {
  final items = graph.quizItems.where((q) => q.conceptId == conceptId);

  final reviewedItems = items.where((q) => q.isFsrs && q.lastReview != null);
  if (reviewedItems.isEmpty) return 1.0;

  final currentTime = now ?? DateTime.now().toUtc();
  var totalR = 0.0;
  for (final item in reviewedItems) {
    totalR += fsrsRetrievability(
      stability: item.stability!,
      fsrsState: item.fsrsState!,
      lastReview: item.lastReview!,
      now: currentTime,
    );
  }
  return totalR / reviewedItems.length;
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
