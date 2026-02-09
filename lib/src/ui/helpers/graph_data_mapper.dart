import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/graph_analyzer.dart';
import '../../models/knowledge_graph.dart';
import '../../models/quiz_item.dart';

/// Mastery state for a concept node, determines its color.
enum MasteryState { locked, due, learning, mastered, fading }

/// Number of days after which a mastered concept starts fading.
const _fadingThresholdDays = 30;

/// Maximum days used for freshness linear decay (maps to 0.3 freshness).
const _maxDecayDays = 60;

/// Maps a [KnowledgeGraph] to the data format expected by flutter_graph_view.
class GraphDataMapper {
  const GraphDataMapper._();

  /// Color for each mastery state.
  static const masteryColors = {
    MasteryState.locked: Colors.grey,
    MasteryState.due: Colors.red,
    MasteryState.learning: Colors.amber,
    MasteryState.mastered: Colors.green,
    MasteryState.fading: Color(0xFF81C784),
  };

  /// Tag name used per mastery state (drives flutter_graph_view coloring).
  static const _masteryTags = {
    MasteryState.locked: 'locked',
    MasteryState.due: 'due',
    MasteryState.learning: 'learning',
    MasteryState.mastered: 'mastered',
    MasteryState.fading: 'fading',
  };

  /// Determines the mastery state of a single concept.
  static MasteryState masteryStateOf(
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
      if (daysSince > _fadingThresholdDays) return MasteryState.fading;
    }

    return MasteryState.mastered;
  }

  /// Compute freshness of a concept (1.0 = just reviewed, 0.3 = 60+ days ago).
  ///
  /// Returns 1.0 if no review dates are available.
  static double freshnessOf(
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

    // Linear decay from 1.0 to 0.3 over _maxDecayDays
    final t = math.min(daysSince / _maxDecayDays, 1.0);
    return 1.0 - (0.7 * t);
  }

  /// Find the oldest `lastReview` timestamp across a set of quiz items.
  static DateTime? _oldestLastReview(Iterable<QuizItem> items) {
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

  /// Convert the full graph to flutter_graph_view data format.
  static Map<String, dynamic> toGraphViewData(KnowledgeGraph graph) {
    final analyzer = GraphAnalyzer(graph);

    final vertexes = <Map<String, dynamic>>[];
    for (final concept in graph.concepts) {
      final state = masteryStateOf(concept.id, graph, analyzer);
      final freshness = freshnessOf(concept.id, graph);
      vertexes.add({
        'id': concept.id,
        'tag': _masteryTags[state]!,
        'tags': <String>[_masteryTags[state]!],
        'data': {
          'name': concept.name,
          'description': concept.description,
          'state': state.name,
          'freshness': freshness,
        },
      });
    }

    final edges = <Map<String, dynamic>>[];
    for (final rel in graph.relationships) {
      edges.add({
        'srcId': rel.fromConceptId,
        'dstId': rel.toConceptId,
        'edgeName': rel.label,
        'ranking': GraphAnalyzer.isDependencyEdge(rel) ? 100 : 50,
      });
    }

    return {'vertexes': vertexes, 'edges': edges};
  }

  /// Tag-to-color map for flutter_graph_view's GraphStyle.
  static Map<String, Color> get tagColorMap => {
        'locked': masteryColors[MasteryState.locked]!,
        'due': masteryColors[MasteryState.due]!,
        'learning': masteryColors[MasteryState.learning]!,
        'mastered': masteryColors[MasteryState.mastered]!,
        'fading': masteryColors[MasteryState.fading]!,
      };
}
