import 'package:material_ui/material_ui.dart';

import '../../engine/mastery_state.dart';
import '../../models/concept.dart';
import '../../models/knowledge_graph.dart';
import '../../models/quiz_item.dart';
import '../../models/relationship.dart';
import '../graph/force_directed_graph_widget.dart';
import 'lab/lab_test_data.dart';

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
    final concepts = List<Concept>.of(labInitialConcepts);
    final relationships = List<Relationship>.of(labInitialRelationships);
    final quizItems = <QuizItem>[
      for (final item in labInitialQuizItems) _applyOverrides(item),
    ];

    // Add batch 2 concepts up to _batch2Count.
    if (_batch2Count > 0) {
      final batch2Slice = labBatch2Concepts.sublist(0, _batch2Count);
      concepts.addAll(batch2Slice);
      final visibleIds = concepts.map((c) => c.id).toSet();
      for (final rel in labBatch2Relationships) {
        if (visibleIds.contains(rel.fromConceptId) &&
            visibleIds.contains(rel.toConceptId)) {
          relationships.add(rel);
        }
      }
      for (final item in labBatch2QuizItems) {
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
          nextReview: labNow,
          lastReview: null,
        );
      case 1: // learning — FSRS state 1 (learning phase)
        return QuizItem(
          id: original.id,
          conceptId: original.conceptId,
          question: original.question,
          answer: original.answer,
          interval: 7,
          nextReview: labNow.add(const Duration(days: 7)),
          lastReview: labNow.subtract(const Duration(days: 1)),
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
          nextReview: labNow.add(const Duration(days: 30)),
          lastReview: labNow.subtract(const Duration(days: 2)),
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
          nextReview: labNow,
          lastReview: labNow.subtract(const Duration(days: 45)),
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
    final lastReview = labNow.subtract(Duration(days: daysSince));
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
    if (_batch2Count >= labBatch2Concepts.length) return;
    _batch2Count++;
    _rebuildGraph();
    setState(() {});
  }

  void _addBatch() {
    if (_batch2Count >= labBatch2Concepts.length) return;
    _batch2Count = labBatch2Concepts.length;
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
                'Add Node (${labInitialConcepts.length + _batch2Count}/${labInitialConcepts.length + labBatch2Concepts.length})',
            onPressed: _batch2Count < labBatch2Concepts.length ? _addNode : null,
          ),
          _ToolbarButton(
            icon: Icons.library_add,
            label: 'Ingest Batch',
            onPressed: _batch2Count < labBatch2Concepts.length ? _addBatch : null,
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
    final allConcepts = List<Concept>.of(labInitialConcepts);
    if (_batch2Count > 0) {
      allConcepts.addAll(labBatch2Concepts.sublist(0, _batch2Count));
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

