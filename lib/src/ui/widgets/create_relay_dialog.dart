import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/concept.dart';
import '../../models/relay_challenge.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/relay_provider.dart';

/// Dialog for creating a new relay challenge.
///
/// Lets the user pick concepts in chain order from the knowledge graph,
/// preview the chain, and create the relay.
class CreateRelayDialog extends ConsumerStatefulWidget {
  const CreateRelayDialog({super.key});

  @override
  ConsumerState<CreateRelayDialog> createState() => _CreateRelayDialogState();
}

class _CreateRelayDialogState extends ConsumerState<CreateRelayDialog> {
  final _titleController = TextEditingController();
  final _selectedConcepts = <Concept>[];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
    final concepts = graph?.concepts.toList() ?? <Concept>[];

    return AlertDialog(
      title: const Text('Create Relay Challenge'),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Relay Title',
                  hintText: 'CI/CD Mastery Chain',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Chain preview
              if (_selectedConcepts.isNotEmpty) ...[
                Text(
                  'Chain (${_selectedConcepts.length} legs):',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _selectedConcepts.length; i++) ...[
                      Chip(
                        label: Text(
                          _selectedConcepts[i].name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: () {
                          setState(() => _selectedConcepts.removeAt(i));
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      if (i < _selectedConcepts.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Icon(Icons.arrow_forward, size: 14),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Concept picker
              Text(
                'Add concepts to the chain:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: concepts.length,
                  itemBuilder: (context, index) {
                    final concept = concepts[index];
                    final alreadySelected = _selectedConcepts.any(
                      (c) => c.id == concept.id,
                    );
                    return ListTile(
                      dense: true,
                      title: Text(
                        concept.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing:
                          alreadySelected
                              ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.green,
                              )
                              : null,
                      onTap:
                          alreadySelected
                              ? null
                              : () {
                                setState(() => _selectedConcepts.add(concept));
                              },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canCreate() ? _createRelay : null,
          child: const Text('Create'),
        ),
      ],
    );
  }

  bool _canCreate() {
    return _titleController.text.isNotEmpty && _selectedConcepts.length >= 2;
  }

  Future<void> _createRelay() async {
    final legs =
        _selectedConcepts
            .map((c) => RelayLeg(conceptId: c.id, conceptName: c.name))
            .toList();

    await ref
        .read(relayProvider.notifier)
        .createRelay(title: _titleController.text, legs: legs);

    if (mounted) Navigator.of(context).pop();
  }
}
