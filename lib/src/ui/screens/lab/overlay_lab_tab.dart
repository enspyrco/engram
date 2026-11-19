import 'package:material_ui/material_ui.dart';

import '../../../models/knowledge_graph.dart';
import '../../../models/network_health.dart';
import '../../graph/force_directed_graph_widget.dart';
import 'lab_test_data.dart';

/// Lab tab for exercising storm and catastrophe overlays.
///
/// Shows the full graph with controls for health tier and storm activation so
/// you can preview each catastrophe visual state without needing real network
/// health data.
class OverlayLabTab extends StatefulWidget {
  const OverlayLabTab({super.key});

  @override
  State<OverlayLabTab> createState() => _OverlayLabTabState();
}

class _OverlayLabTabState extends State<OverlayLabTab> {
  HealthTier _tier = HealthTier.healthy;
  bool _stormActive = false;

  late final KnowledgeGraph _graph;

  @override
  void initState() {
    super.initState();
    // Build full graph (initial + batch 2) so there are enough edges for
    // catastrophe visuals to be interesting.
    _graph = KnowledgeGraph(
      concepts: [...labInitialConcepts, ...labBatch2Concepts],
      relationships: [...labInitialRelationships, ...labBatch2Relationships],
      quizItems: [...labInitialQuizItems, ...labBatch2QuizItems],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder:
                (context, constraints) => ForceDirectedGraphWidget(
                  graph: _graph,
                  layoutWidth: constraints.maxWidth,
                  layoutHeight: constraints.maxHeight,
                  healthTier: _tier,
                  isStormActive: _stormActive,
                ),
          ),
        ),
        _buildControls(context),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          // Health tier dropdown
          const Text('Health Tier:', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          DropdownButton<HealthTier>(
            value: _tier,
            isDense: true,
            items:
                HealthTier.values
                    .map(
                      (tier) => DropdownMenuItem(
                        value: tier,
                        child: Text(
                          tier.name[0].toUpperCase() + tier.name.substring(1),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (tier) {
              if (tier != null) setState(() => _tier = tier);
            },
          ),
          const SizedBox(width: 24),
          // Storm toggle
          const Text('Storm:', style: TextStyle(fontSize: 12)),
          Switch(
            value: _stormActive,
            onChanged: (v) => setState(() => _stormActive = v),
          ),
        ],
      ),
    );
  }
}
