import '../../models/relationship.dart';
import 'graph_node.dart';

/// An edge in the force-directed graph, wrapping a [Relationship] with
/// references to source and target [GraphNode]s.
class GraphEdge {
  GraphEdge({
    required this.relationship,
    required this.source,
    required this.target,
  });

  final Relationship relationship;
  final GraphNode source;
  final GraphNode target;

  /// The resolved semantic type of this edge's relationship.
  RelationshipType get type => relationship.resolvedType;

  /// Whether this edge represents a dependency (prerequisite).
  bool get isDependency => type.isDependency;

  String get label => relationship.label;
}
