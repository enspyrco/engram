import 'package:flutter/material.dart';

import '../../models/knowledge_graph.dart';
import '../../models/network_health.dart';
import '../graph/force_directed_graph_widget.dart';
import '../graph/team_node.dart';

class MindMap extends StatelessWidget {
  const MindMap({
    required this.graph,
    this.teamNodes = const [],
    this.healthTier = HealthTier.healthy,
    this.guardianMap = const {},
    this.currentUserUid,
    super.key,
  });

  final KnowledgeGraph graph;
  final List<TeamNode> teamNodes;
  final HealthTier healthTier;
  final Map<String, String> guardianMap;
  final String? currentUserUid;

  @override
  Widget build(BuildContext context) {
    if (graph.concepts.isEmpty) {
      return const Center(child: Text('No concepts to display'));
    }

    return ForceDirectedGraphWidget(
      graph: graph,
      teamNodes: teamNodes,
      healthTier: healthTier,
      guardianMap: guardianMap,
      currentUserUid: currentUserUid,
    );
  }
}
