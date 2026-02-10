import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/knowledge_graph.dart';
import '../models/quiz_item.dart';
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
MasteryState masteryStateOf(
  String conceptId,
  KnowledgeGraph graph,
  GraphAnalyzer analyzer, {
  DateTime? now,
}) {
  if (!analyzer.isConceptUnlocked(conceptId)) return MasteryState.locked;

  final items = graph.quizItems.where((q) => q.conceptId == conceptId);
  if (items.isEmpty) return MasteryState.mastered;

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

/// Compute freshness of a concept (1.0 = just reviewed, 0.3 = 60+ days ago).
///
/// Returns 1.0 if no review dates are available.
double freshnessOf(
  String conceptId,
  KnowledgeGraph graph, {
  DateTime? now,
}) {
  final items = graph.quizItems.where((q) => q.conceptId == conceptId);
  final oldest = _oldestLastReview(items);
  if (oldest == null) return 1.0;

  final currentTime = now ?? DateTime.now().toUtc();
  final daysSince = currentTime.difference(oldest).inDays;
  if (daysSince <= 0) return 1.0;

  // Linear decay from 1.0 to 0.3 over maxDecayDays
  final t = math.min(daysSince / maxDecayDays, 1.0);
  return 1.0 - (0.7 * t);
}

/// Find the oldest `lastReview` timestamp across a set of quiz items.
DateTime? _oldestLastReview(Iterable<QuizItem> items) {
  DateTime? oldest;
  for (final item in items) {
    if (item.lastReview == null) continue;
    final date = DateTime.parse(item.lastReview!);
    if (oldest == null || date.isBefore(oldest)) {
      oldest = date;
    }
  }
  return oldest;
}
