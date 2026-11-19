import 'package:material_ui/material_ui.dart';

import '../../../models/knowledge_graph.dart';
import '../../graph/force_directed_graph_widget.dart';
import 'lab_test_data.dart';

/// Lab tab for exercising the glow animation on newly ingested nodes.
///
/// Select nodes via chips, hit "Trigger Glow", and watch the 4-second cyan
/// halo fade to zero. The `onGlowComplete` callback clears the selection
/// automatically, just like the real recommendations flow.
class GlowLabTab extends StatefulWidget {
  const GlowLabTab({super.key});

  @override
  State<GlowLabTab> createState() => _GlowLabTabState();
}

class _GlowLabTabState extends State<GlowLabTab> {
  /// Node IDs selected for the next glow trigger.
  final Set<String> _selectedIds = {};

  /// Node IDs currently glowing (passed to the widget).
  Set<String> _glowIds = {};

  late final KnowledgeGraph _graph;

  @override
  void initState() {
    super.initState();
    _graph = KnowledgeGraph(
      concepts: [...labInitialConcepts, ...labBatch2Concepts],
      relationships: [...labInitialRelationships, ...labBatch2Relationships],
      quizItems: [...labInitialQuizItems, ...labBatch2QuizItems],
    );
  }

  void _triggerGlow() {
    if (_selectedIds.isEmpty) return;
    setState(() => _glowIds = Set.of(_selectedIds));
  }

  void _onGlowComplete() {
    setState(() => _glowIds = {});
  }

  @override
  Widget build(BuildContext context) {
    final allConcepts = [...labInitialConcepts, ...labBatch2Concepts];

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder:
                (context, constraints) => ForceDirectedGraphWidget(
                  graph: _graph,
                  layoutWidth: constraints.maxWidth,
                  layoutHeight: constraints.maxHeight,
                  glowNodeIds: _glowIds,
                  onGlowComplete: _onGlowComplete,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Node selector chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    allConcepts.map((concept) {
                      final selected = _selectedIds.contains(concept.id);
                      return FilterChip(
                        label: Text(
                          concept.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedIds.add(concept.id);
                            } else {
                              _selectedIds.remove(concept.id);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 8),
              // Action buttons
              Row(
                children: [
                  FilledButton.icon(
                    onPressed:
                        _selectedIds.isNotEmpty && _glowIds.isEmpty
                            ? _triggerGlow
                            : null,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                      _glowIds.isNotEmpty
                          ? 'Glowing...'
                          : 'Trigger Glow (${_selectedIds.length})',
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed:
                        _selectedIds.isNotEmpty
                            ? () => setState(_selectedIds.clear)
                            : null,
                    child: const Text('Clear Selection'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedIds.addAll(allConcepts.map((c) => c.id));
                      });
                    },
                    child: const Text('Select All'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
