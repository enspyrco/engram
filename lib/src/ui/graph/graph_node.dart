import 'dart:ui';

import '../../engine/mastery_state.dart';
import '../../models/concept.dart';

/// A node in the force-directed graph, wrapping a [Concept] with layout
/// position and computed mastery information.
class GraphNode {
  GraphNode({
    required this.concept,
    required this.masteryState,
    required this.freshness,
    this.position = Offset.zero,
    this.radius = 18.0,
  });

  final Concept concept;
  final MasteryState masteryState;
  final double freshness;
  Offset position;
  final double radius;

  String get id => concept.id;
  String get name => concept.name;
  String get description => concept.description;

  /// Whether a screen-space point falls within this node's circle.
  bool containsPoint(Offset point) {
    return (point - position).distance <= radius;
  }
}
