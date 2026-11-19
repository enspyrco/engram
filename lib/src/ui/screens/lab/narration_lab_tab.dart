import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../engine/highlight_propagation.dart';
import '../../../models/knowledge_graph.dart';
import '../../graph/force_directed_graph_widget.dart';
import 'lab_test_data.dart';

/// Lab tab for exercising sustained narration glow with a fake timeline.
///
/// A local [AnimationController] cycles through concepts on a timer, driving
/// the `sustainedGlowMap` on the graph widget. No API calls — purely visual
/// iteration on how narration glow looks and feels.
class NarrationLabTab extends StatefulWidget {
  const NarrationLabTab({super.key});

  @override
  State<NarrationLabTab> createState() => _NarrationLabTabState();
}

class _NarrationLabTabState extends State<NarrationLabTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final KnowledgeGraph _graph;
  late final List<String> _conceptIds;
  late final Map<String, Set<String>> _adjacencyMap;

  /// Duration per concept in the fake narration cycle.
  static const _conceptDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();

    _graph = KnowledgeGraph(
      concepts: [...labInitialConcepts, ...labBatch2Concepts],
      relationships: [...labInitialRelationships, ...labBatch2Relationships],
      quizItems: [...labInitialQuizItems, ...labBatch2QuizItems],
    );

    _conceptIds = _graph.concepts.map((c) => c.id).toList();

    // Build adjacency map for highlight propagation.
    _adjacencyMap = {};
    for (final r in _graph.relationships) {
      _adjacencyMap.putIfAbsent(r.fromConceptId, () => {}).add(r.toConceptId);
      _adjacencyMap.putIfAbsent(r.toConceptId, () => {}).add(r.fromConceptId);
    }

    // Total animation covers all concepts.
    final totalDuration = _conceptDuration * _conceptIds.length;
    _controller = AnimationController(
      vsync: this,
      duration: totalDuration,
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Compute the sustained glow map based on current animation position.
  Map<String, double> get _glowMap {
    if (!_controller.isAnimating && _controller.value == 0.0) return const {};

    final totalMs = _controller.duration!.inMilliseconds;
    final currentMs = (_controller.value * totalMs).round();
    final conceptMs = _conceptDuration.inMilliseconds;

    // Which concept is the "primary" active one?
    final conceptIndex = math.min(
      currentMs ~/ conceptMs,
      _conceptIds.length - 1,
    );
    final primaryId = _conceptIds[conceptIndex];

    // Compute fade-in/out within the concept window.
    final windowStart = conceptIndex * conceptMs;
    final progress = (currentMs - windowStart) / conceptMs;
    // Quick fade-in (0→0.2), hold, quick fade-out (0.8→1.0).
    final double intensity;
    if (progress < 0.2) {
      intensity = progress / 0.2;
    } else if (progress > 0.8) {
      intensity = (1.0 - progress) / 0.2;
    } else {
      intensity = 1.0;
    }

    final raw = propagateHighlight(
      activeConcepts: {primaryId},
      adjacencyMap: _adjacencyMap,
    );

    // Scale all intensities by the fade envelope.
    if (intensity >= 1.0) return raw;
    return {for (final entry in raw.entries) entry.key: entry.value * intensity};
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller.isAnimating;
    final glowMap = _glowMap;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => ForceDirectedGraphWidget(
              graph: _graph,
              layoutWidth: constraints.maxWidth,
              layoutHeight: constraints.maxHeight,
              sustainedGlowMap: glowMap,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () {
                  if (isPlaying) {
                    _controller.stop();
                  } else {
                    _controller.forward(
                      from: _controller.value == 1.0 ? 0.0 : _controller.value,
                    );
                  }
                  setState(() {});
                },
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(isPlaying ? 'Pause' : 'Play Narration'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _controller.stop();
                  _controller.reset();
                  setState(() {});
                },
                child: const Text('Reset'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LinearProgressIndicator(
                  value: _controller.value,
                  backgroundColor: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
