import 'package:flutter/material.dart';

import '../../engine/mastery_state.dart';
import '../../models/concept.dart';
import '../../models/knowledge_graph.dart';
import '../../models/quiz_item.dart';
import '../../models/relationship.dart';
import '../graph/force_directed_graph_widget.dart';

/// Test bed for the force-directed graph animation.
///
/// Isolates the graph widget from providers, auth, and network to verify
/// animation behavior step by step:
/// - Incremental node addition (pinned force-directed layout)
/// - Temperature scaling and settling behavior
/// - Mastery colors, glow, freshness opacity
/// - Batch node addition (simulated document ingestion)
class GraphLabScreen extends StatefulWidget {
  const GraphLabScreen({super.key});

  @override
  State<GraphLabScreen> createState() => _GraphLabScreenState();
}

class _GraphLabScreenState extends State<GraphLabScreen> {
  /// Number of batch 2 concepts visible (0–5). All 6 initial concepts are
  /// always shown; "Add Node" increments this one at a time.
  int _batch2Count = 0;

  /// Per-concept mastery overrides. Maps concept ID → index in
  /// [due(0), learning(1), mastered(2), fading(3)].
  final Map<String, int> _masteryOverrides = {};

  /// Per-concept freshness overrides (0.3–1.0).
  final Map<String, double> _freshnessOverrides = {};

  /// Concept selected in the visual controls dropdown.
  String? _controlNodeId;

  /// Debug info from the layout engine, updated via [ValueNotifier] so only
  /// the debug overlay rebuilds — not the entire screen.
  final _debugNotifier = ValueNotifier<_DebugInfo>(const _DebugInfo());

  /// Cached graph — rebuilt only when data changes (add node, change mastery).
  late KnowledgeGraph _graph;

  @override
  void initState() {
    super.initState();
    _rebuildGraph();
  }

  @override
  void dispose() {
    _debugNotifier.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Graph construction
  // ---------------------------------------------------------------------------

  void _rebuildGraph() {
    // Always include all 6 initial concepts.
    final concepts = List<Concept>.of(_initialConcepts);
    final relationships = List<Relationship>.of(_initialRelationships);
    final quizItems = <QuizItem>[
      for (final item in _initialQuizItems) _applyOverrides(item),
    ];

    // Add batch 2 concepts up to _batch2Count.
    if (_batch2Count > 0) {
      final batch2Slice = _batch2Concepts.sublist(0, _batch2Count);
      concepts.addAll(batch2Slice);
      final visibleIds = concepts.map((c) => c.id).toSet();
      for (final rel in _batch2Relationships) {
        if (visibleIds.contains(rel.fromConceptId) &&
            visibleIds.contains(rel.toConceptId)) {
          relationships.add(rel);
        }
      }
      for (final item in _batch2QuizItems) {
        if (visibleIds.contains(item.conceptId)) {
          quizItems.add(_applyOverrides(item));
        }
      }
    }

    _graph = KnowledgeGraph(
      concepts: concepts,
      relationships: relationships,
      quizItems: quizItems,
    );
  }

  QuizItem _applyOverrides(QuizItem item) {
    var result = item;
    final masteryIdx = _masteryOverrides[item.conceptId];
    if (masteryIdx != null) {
      result = _quizItemForMasteryIndex(result, masteryIdx);
    }
    final freshness = _freshnessOverrides[item.conceptId];
    if (freshness != null) {
      result = _quizItemWithFreshness(result, freshness);
    }
    return result;
  }

  /// Create a quiz item whose FSRS fields produce the desired mastery state.
  QuizItem _quizItemForMasteryIndex(QuizItem original, int index) {
    switch (index) {
      case 0: // due — no lastReview, no FSRS fields
        return QuizItem(
          id: original.id,
          conceptId: original.conceptId,
          question: original.question,
          answer: original.answer,
          interval: 0,
          nextReview: _now,
          lastReview: null,
        );
      case 1: // learning — FSRS state 1 (learning phase)
        return QuizItem(
          id: original.id,
          conceptId: original.conceptId,
          question: original.question,
          answer: original.answer,
          interval: 7,
          nextReview: _now.add(const Duration(days: 7)),
          lastReview: _now.subtract(const Duration(days: 1)),
          difficulty: 5.0,
          stability: 5.0,
          fsrsState: 1,
          lapses: 0,
        );
      case 2: // mastered — FSRS state 2 (review), high stability
        return QuizItem(
          id: original.id,
          conceptId: original.conceptId,
          question: original.question,
          answer: original.answer,
          interval: 30,
          nextReview: _now.add(const Duration(days: 30)),
          lastReview: _now.subtract(const Duration(days: 2)),
          difficulty: 5.0,
          stability: 100.0,
          fsrsState: 2,
          lapses: 0,
        );
      case 3: // fading — FSRS state 2 but old lastReview (45 days ago)
        return QuizItem(
          id: original.id,
          conceptId: original.conceptId,
          question: original.question,
          answer: original.answer,
          interval: 30,
          nextReview: _now,
          lastReview: _now.subtract(const Duration(days: 45)),
          difficulty: 5.0,
          stability: 1000.0,
          fsrsState: 2,
          lapses: 0,
        );
      default:
        return original;
    }
  }

  /// Adjust a quiz item's lastReview to produce the desired freshness value.
  /// freshness = 1.0 - 0.7 * min(daysSince / 60, 1.0)
  /// -> daysSince = (1.0 - freshness) / 0.7 * 60
  QuizItem _quizItemWithFreshness(QuizItem original, double freshness) {
    final daysSince = ((1.0 - freshness) / 0.7 * 60).round();
    final lastReview = _now.subtract(Duration(days: daysSince));
    return QuizItem(
      id: original.id,
      conceptId: original.conceptId,
      question: original.question,
      answer: original.answer,
      interval: original.interval,
      nextReview: original.nextReview,
      lastReview: lastReview,
      difficulty: original.difficulty,
      stability: original.stability,
      fsrsState: original.fsrsState,
      lapses: original.lapses,
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _addNode() {
    if (_batch2Count >= _batch2Concepts.length) return;
    _batch2Count++;
    _rebuildGraph();
    setState(() {});
  }

  void _addBatch() {
    if (_batch2Count >= _batch2Concepts.length) return;
    _batch2Count = _batch2Concepts.length;
    _rebuildGraph();
    setState(() {});
  }

  void _reset() {
    _batch2Count = 0;
    _masteryOverrides.clear();
    _freshnessOverrides.clear();
    _controlNodeId = null;
    _rebuildGraph();
    setState(() {});
  }

  void _cycleMastery() {
    if (_controlNodeId == null) return;
    final current = _masteryOverrides[_controlNodeId!] ?? -1;
    final next = current < 0 ? 0 : (current + 1) % 4;
    _masteryOverrides[_controlNodeId!] = next;
    _freshnessOverrides.remove(_controlNodeId!);
    _rebuildGraph();
    setState(() {});
  }

  void _onDebugTick(
    double temperature,
    int pinnedCount,
    int totalCount,
    bool isSettled,
  ) {
    _debugNotifier.value = _DebugInfo(
      temperature: temperature,
      pinnedCount: pinnedCount,
      totalCount: totalCount,
      isSettled: isSettled,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graph Lab'),
        actions: [
          _ToolbarButton(
            icon: Icons.add_circle_outline,
            label:
                'Add Node (${_initialConcepts.length + _batch2Count}/${_initialConcepts.length + _batch2Concepts.length})',
            onPressed: _batch2Count < _batch2Concepts.length ? _addNode : null,
          ),
          _ToolbarButton(
            icon: Icons.library_add,
            label: 'Ingest Batch',
            onPressed: _batch2Count < _batch2Concepts.length ? _addBatch : null,
          ),
          _ToolbarButton(
            icon: Icons.restart_alt,
            label: 'Reset',
            onPressed: _reset,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder:
                  (context, constraints) => Stack(
                    children: [
                      ForceDirectedGraphWidget(
                        graph: _graph,
                        layoutWidth: constraints.maxWidth,
                        layoutHeight: constraints.maxHeight,
                        onDebugTick: _onDebugTick,
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _DebugOverlay(notifier: _debugNotifier),
                      ),
                      const Positioned(
                        left: 8,
                        top: 8,
                        child: _MasteryLegend(),
                      ),
                    ],
                  ),
            ),
          ),
          _buildVisualControls(),
        ],
      ),
    );
  }

  Widget _buildVisualControls() {
    // Gather all currently visible concepts for the dropdown.
    final allConcepts = List<Concept>.of(_initialConcepts);
    if (_batch2Count > 0) {
      allConcepts.addAll(_batch2Concepts.sublist(0, _batch2Count));
    }

    // Ensure _controlNodeId is still valid.
    if (_controlNodeId != null &&
        !allConcepts.any((c) => c.id == _controlNodeId)) {
      _controlNodeId = null;
    }

    final masteryLabel = _masteryLabelForOverride(
      _controlNodeId != null ? _masteryOverrides[_controlNodeId!] : null,
    );
    final currentFreshness =
        _controlNodeId != null
            ? (_freshnessOverrides[_controlNodeId!] ?? 1.0)
            : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          // Node selector
          DropdownButton<String>(
            value: _controlNodeId,
            hint: const Text('Select node'),
            isDense: true,
            items:
                allConcepts
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (id) => setState(() => _controlNodeId = id),
          ),
          const SizedBox(width: 12),
          // Cycle mastery
          OutlinedButton.icon(
            onPressed: _controlNodeId != null ? _cycleMastery : null,
            icon: const Icon(Icons.swap_vert, size: 16),
            label: Text(
              _controlNodeId != null ? 'Mastery: $masteryLabel' : 'Cycle',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          // Freshness slider
          const Text('Freshness:', style: TextStyle(fontSize: 12)),
          SizedBox(
            width: 140,
            child: Slider(
              value: currentFreshness,
              min: 0.3,
              max: 1.0,
              divisions: 14,
              label: '${(currentFreshness * 100).round()}%',
              onChanged:
                  _controlNodeId != null
                      ? (v) {
                        _freshnessOverrides[_controlNodeId!] = v;
                        _rebuildGraph();
                        setState(() {});
                      }
                      : null,
            ),
          ),
          Text(
            '${(currentFreshness * 100).round()}%',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _masteryLabelForOverride(int? index) {
    if (index == null) return 'default';
    return const ['Due', 'Learning', 'Mastered', 'Fading'][index];
  }
}

// ---------------------------------------------------------------------------
// Small helper widgets
// ---------------------------------------------------------------------------

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _DebugInfo {
  const _DebugInfo({
    this.temperature = 0,
    this.pinnedCount = 0,
    this.totalCount = 0,
    this.isSettled = true,
  });

  final double temperature;
  final int pinnedCount;
  final int totalCount;
  final bool isSettled;
}

class _DebugOverlay extends StatelessWidget {
  const _DebugOverlay({required this.notifier});

  final ValueNotifier<_DebugInfo> notifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_DebugInfo>(
      valueListenable: notifier,
      builder:
          (_, info, __) => Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 11,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Temp: ${info.temperature.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: info.isSettled ? Colors.green : Colors.orange,
                    ),
                  ),
                  Text(
                    'Pinned: ${info.pinnedCount} / ${info.totalCount}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    info.isSettled ? 'SETTLED' : 'ANIMATING',
                    style: TextStyle(
                      color: info.isSettled ? Colors.green : Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _MasteryLegend extends StatelessWidget {
  const _MasteryLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Mastery States',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in masteryColors.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: entry.value,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.key.name[0].toUpperCase() +
                        entry.key.name.substring(1),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _now = DateTime.now().toUtc();

// ---------------------------------------------------------------------------
// Initial graph: 6 concepts, 5 relationships, 6 quiz items.
//
// Topology:
//   A (mastered)  <-depends on-  B (learning)
//   A  --relates to-->  C (due)
//   C  <-depends on-  D (locked -- C is unreviewed so D can't unlock)
//   A  <-relates to-  E (fading)
//   E  <-relates to-  F (mastered)
//
// Start with 3 (A, B, C), add D/E/F one at a time via "Add Node".
// ---------------------------------------------------------------------------

final _initialConcepts = [
  Concept(
    id: 'a',
    name: 'Spaced Repetition',
    description:
        'Reviewing material at increasing intervals to combat forgetting',
    sourceDocumentId: 'doc-lab',
  ),
  Concept(
    id: 'b',
    name: 'Leitner System',
    description: 'Card-box system that sorts flashcards by mastery level',
    sourceDocumentId: 'doc-lab',
  ),
  Concept(
    id: 'c',
    name: 'Active Recall',
    description:
        'Actively retrieving information from memory rather than re-reading',
    sourceDocumentId: 'doc-lab',
  ),
  Concept(
    id: 'd',
    name: 'FSRS Algorithm',
    description: 'Free Spaced Repetition Scheduler — modern successor to SM-2',
    sourceDocumentId: 'doc-lab',
  ),
  Concept(
    id: 'e',
    name: 'Forgetting Curve',
    description: 'Ebbinghaus curve showing exponential memory decay over time',
    sourceDocumentId: 'doc-lab',
  ),
  Concept(
    id: 'f',
    name: 'Memory Palace',
    description: 'Method of loci — placing items in imagined spatial locations',
    sourceDocumentId: 'doc-lab',
  ),
];

final _initialRelationships = [
  const Relationship(
    id: 'r1',
    fromConceptId: 'b',
    toConceptId: 'a',
    label: 'depends on',
  ),
  const Relationship(
    id: 'r2',
    fromConceptId: 'd',
    toConceptId: 'c',
    label: 'depends on',
  ),
  const Relationship(
    id: 'r3',
    fromConceptId: 'c',
    toConceptId: 'a',
    label: 'relates to',
  ),
  const Relationship(
    id: 'r4',
    fromConceptId: 'e',
    toConceptId: 'a',
    label: 'relates to',
  ),
  const Relationship(
    id: 'r5',
    fromConceptId: 'f',
    toConceptId: 'e',
    label: 'relates to',
  ),
];

final _initialQuizItems = [
  // A -> mastered: FSRS review state, high stability, recent review
  QuizItem(
    id: 'q1',
    conceptId: 'a',
    question: 'What is spaced repetition?',
    answer: 'Reviewing at increasing intervals to combat forgetting',
    interval: 30,
    nextReview: _now.add(const Duration(days: 30)),
    lastReview: _now.subtract(const Duration(days: 2)),
    difficulty: 5.0,
    stability: 100.0,
    fsrsState: 2,
    lapses: 0,
  ),
  // B -> learning: FSRS learning state, low stability
  QuizItem(
    id: 'q2',
    conceptId: 'b',
    question: 'What is the Leitner system?',
    answer: 'A card-box sorting system for spaced review',
    interval: 7,
    nextReview: _now.add(const Duration(days: 7)),
    lastReview: _now.subtract(const Duration(days: 1)),
    difficulty: 5.0,
    stability: 5.0,
    fsrsState: 1,
    lapses: 0,
  ),
  // C -> due: never reviewed
  QuizItem(
    id: 'q3',
    conceptId: 'c',
    question: 'What is active recall?',
    answer: 'Actively retrieving information from memory',
    interval: 0,
    nextReview: _now,
    lastReview: null,
  ),
  // D -> locked: C is its prerequisite and C is not graduated
  QuizItem(
    id: 'q4',
    conceptId: 'd',
    question: 'What is FSRS?',
    answer: 'Free Spaced Repetition Scheduler',
    interval: 0,
    nextReview: _now,
    lastReview: null,
  ),
  // E -> fading: FSRS review state but lastReview > 30 days ago
  QuizItem(
    id: 'q5',
    conceptId: 'e',
    question: 'What is the forgetting curve?',
    answer: 'Exponential memory decay over time (Ebbinghaus)',
    interval: 30,
    nextReview: _now,
    lastReview: _now.subtract(const Duration(days: 45)),
    difficulty: 5.0,
    stability: 1000.0,
    fsrsState: 2,
    lapses: 0,
  ),
  // F -> mastered: FSRS review state, high stability, recent review
  QuizItem(
    id: 'q6',
    conceptId: 'f',
    question: 'What is a memory palace?',
    answer: 'Method of loci — spatial memory technique',
    interval: 25,
    nextReview: _now.add(const Duration(days: 25)),
    lastReview: _now.subtract(const Duration(days: 3)),
    difficulty: 5.0,
    stability: 80.0,
    fsrsState: 2,
    lapses: 0,
  ),
];

// ---------------------------------------------------------------------------
// Batch 2: simulated second document ingestion — "Learning Techniques".
//
// 5 new concepts that connect to existing nodes A and C.
// Topology:
//   G (learning)  ──relates to──>  A
//   H (due)       ──relates to──>  C
//   I (locked)    ──depends on──>  C  (C is due, so I is locked)
//   J (locked)    ──depends on──>  H  (H is due, so J is locked)
//   K (due)       ──relates to──>  G
// ---------------------------------------------------------------------------

final _batch2Concepts = [
  Concept(
    id: 'g',
    name: 'Interleaving',
    description: 'Mixing different topics during study sessions',
    sourceDocumentId: 'doc-lab-2',
  ),
  Concept(
    id: 'h',
    name: 'Desirable Difficulty',
    description: 'Making learning harder to improve long-term retention',
    sourceDocumentId: 'doc-lab-2',
  ),
  Concept(
    id: 'i',
    name: 'Testing Effect',
    description: 'Taking tests improves long-term retention more than re-study',
    sourceDocumentId: 'doc-lab-2',
  ),
  Concept(
    id: 'j',
    name: 'Elaborative Interrogation',
    description: 'Asking "why" and "how" questions to deepen understanding',
    sourceDocumentId: 'doc-lab-2',
  ),
  Concept(
    id: 'k',
    name: 'Dual Coding',
    description:
        'Combining verbal and visual information for stronger encoding',
    sourceDocumentId: 'doc-lab-2',
  ),
];

final _batch2Relationships = [
  const Relationship(
    id: 'r6',
    fromConceptId: 'g',
    toConceptId: 'a',
    label: 'relates to',
  ),
  const Relationship(
    id: 'r7',
    fromConceptId: 'h',
    toConceptId: 'c',
    label: 'relates to',
  ),
  const Relationship(
    id: 'r8',
    fromConceptId: 'i',
    toConceptId: 'c',
    label: 'depends on',
  ),
  const Relationship(
    id: 'r9',
    fromConceptId: 'j',
    toConceptId: 'h',
    label: 'depends on',
  ),
  const Relationship(
    id: 'r10',
    fromConceptId: 'k',
    toConceptId: 'g',
    label: 'relates to',
  ),
];

final _batch2QuizItems = [
  // G -> learning: FSRS learning state
  QuizItem(
    id: 'q7',
    conceptId: 'g',
    question: 'What is interleaving?',
    answer: 'Mixing different topics during study sessions',
    interval: 7,
    nextReview: _now.add(const Duration(days: 7)),
    lastReview: _now.subtract(const Duration(days: 1)),
    difficulty: 5.0,
    stability: 5.0,
    fsrsState: 1,
    lapses: 0,
  ),
  // H -> due: never reviewed
  QuizItem(
    id: 'q8',
    conceptId: 'h',
    question: 'What is desirable difficulty?',
    answer: 'Making learning harder to improve retention',
    interval: 0,
    nextReview: _now,
    lastReview: null,
  ),
  // I -> locked (depends on C which is due)
  QuizItem(
    id: 'q9',
    conceptId: 'i',
    question: 'What is the testing effect?',
    answer: 'Taking tests improves long-term retention',
    interval: 0,
    nextReview: _now,
    lastReview: null,
  ),
  // J -> locked (depends on H which is due)
  QuizItem(
    id: 'q10',
    conceptId: 'j',
    question: 'What is elaborative interrogation?',
    answer: 'Asking why and how to deepen understanding',
    interval: 0,
    nextReview: _now,
    lastReview: null,
  ),
  // K -> due: never reviewed
  QuizItem(
    id: 'q11',
    conceptId: 'k',
    question: 'What is dual coding?',
    answer: 'Combining verbal and visual information',
    interval: 0,
    nextReview: _now,
    lastReview: null,
  ),
];
