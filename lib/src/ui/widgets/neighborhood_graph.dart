import 'package:material_ui/material_ui.dart';

import '../../engine/neighborhood.dart';
import '../../models/knowledge_graph.dart';
import '../graph/force_directed_graph_widget.dart';

/// A compact, non-interactive knowledge graph showing the 1-hop neighborhood
/// of a concept. Used during quiz answer reveal to provide dual coding —
/// visual spatial encoding alongside verbal question/answer.
class NeighborhoodGraph extends StatelessWidget {
  const NeighborhoodGraph({
    required this.conceptId,
    required this.graph,
    super.key,
  });

  final String conceptId;
  final KnowledgeGraph graph;

  @override
  Widget build(BuildContext context) {
    final subgraph = neighborhoodOf(conceptId, graph);

    // No point showing a lone node — need at least center + 1 neighbor.
    if (subgraph.concepts.length < 2) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ClipRect(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) => ForceDirectedGraphWidget(
              graph: subgraph,
              layoutWidth: constraints.maxWidth,
              layoutHeight: constraints.maxHeight,
              sustainedGlowMap: {conceptId: 1.0},
            ),
          ),
        ),
      ),
    );
  }
}
