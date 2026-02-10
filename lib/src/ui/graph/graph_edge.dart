import '../../engine/graph_analyzer.dart';
import '../../models/relationship.dart';
import 'graph_node.dart';

/// An edge in the force-directed graph, wrapping a [Relationship] with
/// references to source and target [GraphNode]s.
class GraphEdge {
  GraphEdge({
    required this.relationship,
    required this.source,
    required this.target,
  }) : isDependency = GraphAnalyzer.isDependencyEdge(relationship);

  final Relationship relationship;
  final GraphNode source;
  final GraphNode target;
  final bool isDependency;

  String get label => relationship.label;
}
