import 'package:graphs/graphs.dart' as graphs;

import '../models/concept.dart';
import '../models/knowledge_graph.dart';
import '../models/relationship.dart';

/// Analyzes a [KnowledgeGraph] to compute dependency structure, mastery,
/// and topological ordering. All graph computation lives here so that
/// [KnowledgeGraph] stays immutable and purely data-oriented.
class GraphAnalyzer {
  GraphAnalyzer(this._graph);

  final KnowledgeGraph _graph;

  /// Adjacency list: conceptId → set of prerequisite concept IDs.
  late final Map<String, Set<String>> _prerequisites = _buildPrerequisites();

  /// Adjacency list: conceptId → set of dependent concept IDs.
  late final Map<String, Set<String>> _dependents = _buildDependents();

  /// Concept IDs that have quiz items, grouped for mastery lookups.
  late final Map<String, List<int>> _conceptRepetitions =
      _buildConceptRepetitions();

  /// Parent → children adjacency map for sub-concept relationships.
  late final Map<String, Set<String>> _children = _buildChildren();

  /// Concept ID → Concept lookup.
  late final Map<String, Concept> _conceptMap = {
    for (final c in _graph.concepts) c.id: c,
  };

  /// Whether [relationship] represents a dependency (prerequisite) edge.
  static bool isDependencyEdge(Relationship relationship) =>
      relationship.resolvedType.isDependency;

  /// The concept IDs that [conceptId] directly depends on.
  Set<String> prerequisitesOf(String conceptId) =>
      _prerequisites[conceptId] ?? const {};

  /// The concept IDs that directly depend on [conceptId].
  Set<String> dependentsOf(String conceptId) =>
      _dependents[conceptId] ?? const {};

  /// The child concept IDs of a parent concept.
  Set<String> childrenOf(String conceptId) => _children[conceptId] ?? const {};

  /// Whether this concept has been split into sub-concepts.
  bool hasChildren(String conceptId) =>
      _children.containsKey(conceptId) && _children[conceptId]!.isNotEmpty;

  /// A concept is mastered when all its quiz items have repetitions >= 1.
  /// Concepts with no quiz items are considered mastered (informational nodes).
  ///
  /// If the concept has children (was split), it's mastered only when ALL
  /// children are mastered.
  bool isConceptMastered(String conceptId, {Set<String>? visited}) {
    final seen = visited ?? <String>{};
    if (!seen.add(conceptId)) return true; // cycle guard

    if (hasChildren(conceptId)) {
      return childrenOf(
        conceptId,
      ).every((childId) => isConceptMastered(childId, visited: seen));
    }

    final reps = _conceptRepetitions[conceptId];
    if (reps == null || reps.isEmpty) return true;
    return reps.every((r) => r >= 1);
  }

  /// A concept is unlocked when all its prerequisites are mastered.
  /// Children inherit their parent's unlock status.
  bool isConceptUnlocked(String conceptId) {
    final concept = _conceptMap[conceptId];
    if (concept != null && concept.parentConceptId != null) {
      return isConceptUnlocked(concept.parentConceptId!);
    }
    return prerequisitesOf(conceptId).every(isConceptMastered);
  }

  /// Concepts with no prerequisites (entry points into the graph).
  late final List<String> foundationalConcepts =
      _graph.concepts
          .where((c) => prerequisitesOf(c.id).isEmpty)
          .map((c) => c.id)
          .toList();

  /// Concepts whose prerequisites are all mastered.
  late final List<String> unlockedConcepts =
      _graph.concepts
          .where((c) => isConceptUnlocked(c.id))
          .map((c) => c.id)
          .toList();

  /// Concepts with at least one unmastered prerequisite.
  late final List<String> lockedConcepts =
      _graph.concepts
          .where((c) => !isConceptUnlocked(c.id))
          .map((c) => c.id)
          .toList();

  /// Returns a topological ordering of concept IDs respecting dependency
  /// edges, or `null` if the graph contains cycles.
  List<String>? topologicalSort() {
    final conceptIds = {for (final c in _graph.concepts) c.id};
    try {
      return graphs.topologicalSort<String>(
        conceptIds,
        (id) => dependentsOf(id).where(conceptIds.contains),
      );
    } on graphs.CycleException {
      return null;
    }
  }

  /// Whether the dependency graph contains cycles.
  bool hasCycles() => topologicalSort() == null;

  // ── Private helpers ──────────────────────────────────────────────

  Map<String, Set<String>> _buildPrerequisites() {
    final map = <String, Set<String>>{};
    for (final r in _graph.relationships) {
      if (!isDependencyEdge(r)) continue;
      // "A depends on B" means fromConcept depends on toConcept.
      map.putIfAbsent(r.fromConceptId, () => {}).add(r.toConceptId);
    }
    return map;
  }

  Map<String, Set<String>> _buildDependents() {
    final map = <String, Set<String>>{};
    for (final r in _graph.relationships) {
      if (!isDependencyEdge(r)) continue;
      map.putIfAbsent(r.toConceptId, () => {}).add(r.fromConceptId);
    }
    return map;
  }

  Map<String, List<int>> _buildConceptRepetitions() {
    final map = <String, List<int>>{};
    for (final q in _graph.quizItems) {
      map.putIfAbsent(q.conceptId, () => []).add(q.repetitions);
    }
    return map;
  }

  Map<String, Set<String>> _buildChildren() {
    final map = <String, Set<String>>{};
    for (final c in _graph.concepts) {
      if (c.parentConceptId != null) {
        map.putIfAbsent(c.parentConceptId!, () => {}).add(c.id);
      }
    }
    return map;
  }
}
