import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/split_concept_provider.dart';

/// Bottom sheet for reviewing and applying sub-concept split suggestions.
class SplitConceptSheet extends ConsumerWidget {
  const SplitConceptSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(splitConceptProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: switch (state.phase) {
            SplitPhase.loading || SplitPhase.applying => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  state.phase == SplitPhase.loading
                      ? 'Generating sub-concepts...'
                      : 'Applying split...',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            SplitPhase.reviewing => _ReviewingView(
              scrollController: scrollController,
            ),
            SplitPhase.error => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to generate suggestions',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  state.errorMessage ?? 'Unknown error',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    ref.read(splitConceptProvider.notifier).reset();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

class _ReviewingView extends ConsumerWidget {
  const _ReviewingView({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(splitConceptProvider);
    final suggestion = state.suggestion;
    if (suggestion == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Split into sub-concepts', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Select which sub-concepts to create:',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: suggestion.entries.length,
            itemBuilder: (context, index) {
              final entry = suggestion.entries[index];
              final isSelected = state.selectedIndices.contains(index);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged:
                      (_) => ref
                          .read(splitConceptProvider.notifier)
                          .toggleSubConcept(index),
                  title: Text(entry.concept.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.concept.description),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.quizItems.length} quiz item${entry.quizItems.length == 1 ? '' : 's'}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(splitConceptProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed:
                    state.selectedIndices.isEmpty
                        ? null
                        : () async {
                          await ref
                              .read(splitConceptProvider.notifier)
                              .applySplit();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                child: Text('Apply (${state.selectedIndices.length})'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
