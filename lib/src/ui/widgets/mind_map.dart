import 'package:flutter/material.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';

import '../../models/knowledge_graph.dart';
import '../helpers/graph_data_mapper.dart';

class MindMap extends StatelessWidget {
  const MindMap({required this.graph, super.key});

  final KnowledgeGraph graph;

  @override
  Widget build(BuildContext context) {
    if (graph.concepts.isEmpty) {
      return const Center(child: Text('No concepts to display'));
    }

    final data = GraphDataMapper.toGraphViewData(graph);

    return FlutterGraphWidget(
      data: data,
      algorithm: ForceDirected(),
      convertor: MapConvertor(),
      options: Options()
        ..enableHit = true
        ..graphStyle = (GraphStyle()..tagColor = GraphDataMapper.tagColorMap)
        ..vertexPanelBuilder = _buildVertexPanel,
    );
  }

  Widget _buildVertexPanel(Vertex hoverVertex) {
    final vertexData = hoverVertex.data as Map<String, dynamic>?;
    final name = vertexData?['name'] as String? ?? hoverVertex.id.toString();
    final description = vertexData?['description'] as String? ?? '';
    final stateStr = vertexData?['state'] as String? ?? '';
    final freshness = vertexData?['freshness'] as double?;

    return Card(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _colorForState(stateStr),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stateStr.isNotEmpty
                      ? stateStr[0].toUpperCase() + stateStr.substring(1)
                      : '',
                  style: TextStyle(
                    fontSize: 11,
                    color: _colorForState(stateStr),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (freshness != null && freshness < 1.0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${(freshness * 100).round()}% fresh',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForState(String state) {
    return switch (state) {
      'locked' => GraphDataMapper.masteryColors[MasteryState.locked]!,
      'due' => GraphDataMapper.masteryColors[MasteryState.due]!,
      'learning' => GraphDataMapper.masteryColors[MasteryState.learning]!,
      'mastered' => GraphDataMapper.masteryColors[MasteryState.mastered]!,
      'fading' => GraphDataMapper.masteryColors[MasteryState.fading]!,
      _ => Colors.grey,
    };
  }
}
