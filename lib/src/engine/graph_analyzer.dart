import '../models/knowledge_graph.dart';
import '../models/relationship.dart';

/// Labels (case-insensitive substrings) that indicate a dependency edge.
const _dependencyKeywords = [
  'depends on',
  'requires',
  'prerequisite',
  'builds on',
  'assumes',
];

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

  /// Whether [relationship] represents a dependency (prerequisite) edge.
  static bool isDependencyEdge(Relationship relationship) {
    final lower = relationship.label.toLowerCase();
    return _dependencyKeywords.any((kw) => lower.contains(kw));
  }

  /// The concept IDs that [conceptId] directly depends on.
  Set<String> prerequisitesOf(String conceptId) =>
      _prerequisites[conceptId] ?? const {};

  /// The concept IDs that directly depend on [conceptId].
  Set<String> dependentsOf(String conceptId) =>
      _dependents[conceptId] ?? const {};

  /// A concept is mastered when all its quiz items have repetitions >= 1.
  /// Concepts with no quiz items are considered mastered (informational nodes).
  bool isConceptMastered(String conceptId) {
    final reps = _conceptRepetitions[conceptId];
    if (reps == null || reps.isEmpty) return true;
    return reps.every((r) => r >= 1);
  }

  /// A concept is unlocked when all its prerequisites are mastered.
  bool isConceptUnlocked(String conceptId) {
    return prerequisitesOf(conceptId).every(isConceptMastered);
  }

  /// Concepts with no prerequisites (entry points into the graph).
  late final List<String> foundationalConcepts = _graph.concepts
      .where((c) => prerequisitesOf(c.id).isEmpty)
      .map((c) => c.id)
      .toList();

  /// Concepts whose prerequisites are all mastered.
  late final List<String> unlockedConcepts = _graph.concepts
      .where((c) => isConceptUnlocked(c.id))
      .map((c) => c.id)
      .toList();

  /// Concepts with at least one unmastered prerequisite.
  late final List<String> lockedConcepts = _graph.concepts
      .where((c) => !isConceptUnlocked(c.id))
      .map((c) => c.id)
      .toList();

  /// Returns a topological ordering of concept IDs respecting dependency
  /// edges, or `null` if the graph contains cycles.
  List<String>? topologicalSort() {
    final conceptIds = {for (final c in _graph.concepts) c.id};
    final inDegree = <String, int>{for (final id in conceptIds) id: 0};

    for (final id in conceptIds) {
      for (final prereq in prerequisitesOf(id)) {
        if (conceptIds.contains(prereq)) {
          inDegree[id] = (inDegree[id] ?? 0) + 1;
        }
      }
    }

    final queue = <String>[
      for (final id in conceptIds)
        if (inDegree[id] == 0) id,
    ];
    final sorted = <String>[];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      sorted.add(current);

      for (final dep in dependentsOf(current)) {
        if (!conceptIds.contains(dep)) continue;
        inDegree[dep] = (inDegree[dep] ?? 1) - 1;
        if (inDegree[dep] == 0) {
          queue.add(dep);
        }
      }
    }

    return sorted.length == conceptIds.length ? sorted : null;
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
}
