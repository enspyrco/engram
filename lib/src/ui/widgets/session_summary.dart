import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quiz_session_state.dart';
import '../../providers/graph_analysis_provider.dart';
import '../../providers/knowledge_graph_provider.dart';

class SessionSummary extends ConsumerWidget {
  const SessionSummary({
    required this.state,
    required this.onDone,
    super.key,
  });

  final QuizSessionState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final analyzer = ref.watch(graphAnalysisProvider);
    final graph = ref.watch(knowledgeGraphProvider).valueOrNull;

    // Find locked concepts that are close to unlocking
    // (all prerequisites mastered except concepts reviewed in this session)
    final unlockingNext = <String>[];
    if (analyzer != null && graph != null) {
      for (final conceptId in analyzer.lockedConcepts) {
        final prereqs = analyzer.prerequisitesOf(conceptId);
        final unmasteredPrereqs =
            prereqs.where((p) => !analyzer.isConceptMastered(p)).toList();
        // If only 1-2 prerequisites remain unmastered, it's "close"
        if (unmasteredPrereqs.isNotEmpty && unmasteredPrereqs.length <= 2) {
          final concept = graph.concepts
              .where((c) => c.id == conceptId)
              .firstOrNull;
          if (concept != null) {
            unlockingNext.add(concept.name);
          }
        }
      }
    }

    return Center(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.correctPercent >= 80
                    ? Icons.celebration
                    : Icons.trending_up,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                state.isComeback ? 'Great to have you back!' : 'Session Complete',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                '${state.reviewedCount} reviewed',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${state.correctCount} correct (${state.correctPercent.round()}%)',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: state.correctPercent >= 60
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unlockingNext.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open, size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text('Almost unlocking:', style: theme.textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 4),
                ...unlockingNext.take(3).map(
                      (name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(name, style: theme.textTheme.bodyMedium),
                      ),
                    ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onDone,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
