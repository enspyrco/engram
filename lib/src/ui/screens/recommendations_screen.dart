import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/recommendation_evaluation.dart';
import '../../models/knowledge_gap.dart';
import '../../models/recommendation.dart';
import '../../providers/gap_analysis_provider.dart';
import '../../providers/glow_node_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../navigation_shell.dart';

/// Screen showing knowledge gaps and recommended documents to fill them.
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recState = ref.watch(recommendationProvider);
    final gaps = ref.watch(gapAnalysisProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Curiosity Engine'),
        actions: [
          if (recState.phase != RecommendationPhase.searching &&
              recState.phase != RecommendationPhase.evaluating &&
              recState.phase != RecommendationPhase.analyzing)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Scan for recommendations',
              onPressed: () {
                ref
                    .read(recommendationProvider.notifier)
                    .findRecommendations();
              },
            ),
        ],
      ),
      body: _buildBody(context, recState, gaps),
    );
  }

  Widget _buildBody(
    BuildContext context,
    RecommendationState recState,
    List<KnowledgeGap> gaps,
  ) {
    if (recState.phase == RecommendationPhase.analyzing ||
        recState.phase == RecommendationPhase.searching ||
        recState.phase == RecommendationPhase.evaluating) {
      return _LoadingView(phase: recState.phase);
    }

    if (recState.phase == RecommendationPhase.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: ${recState.errorMessage}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Gap summary section.
        if (gaps.isNotEmpty) ...[
          Text(
            '${gaps.length} knowledge gap${gaps.length == 1 ? '' : 's'} detected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final gap in gaps.take(5)) _GapChip(gap: gap),
          const SizedBox(height: 24),
        ] else ...[
          const _EmptyGapsMessage(),
          const SizedBox(height: 24),
        ],

        // Recommendations section.
        if (recState.phase == RecommendationPhase.done) ...[
          if (recState.recommendations.isNotEmpty) ...[
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final rec in recState.recommendations)
              _RecommendationCard(recommendation: rec),
          ] else ...[
            const _EmptyRecommendationsMessage(),
          ],
        ] else if (recState.phase == RecommendationPhase.idle &&
            gaps.isNotEmpty) ...[
          const _ScanPrompt(),
        ],
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.phase});

  final RecommendationPhase phase;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      RecommendationPhase.analyzing => 'Analyzing knowledge gaps...',
      RecommendationPhase.searching => 'Searching Outline wiki...',
      RecommendationPhase.evaluating => 'Evaluating candidates with Claude...',
      RecommendationPhase.idle ||
      RecommendationPhase.done ||
      RecommendationPhase.error => 'Working...',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }
}

class _GapChip extends StatelessWidget {
  const _GapChip({required this.gap});

  final KnowledgeGap gap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (gap.type) {
      GapType.clusterIsolation => Icons.call_split,
      GapType.structuralThinness => Icons.link_off,
      GapType.relationshipTypeGap => Icons.compare_arrows,
      GapType.criticalBottleneck => Icons.warning_amber,
    };

    final severityColor = gap.severity > 0.6
        ? Theme.of(context).colorScheme.error
        : gap.severity > 0.3
            ? Colors.amber
            : Colors.grey;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: severityColor),
        title: Text(
          gap.type.name.replaceAllMapped(
            RegExp(r'[A-Z]'),
            (m) => ' ${m[0]!.toLowerCase()}',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          gap.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${(gap.severity * 100).toInt()}%',
          style: TextStyle(color: severityColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingestResult = ref.watch(
      recommendationProvider.select(
        (s) => s.ingestResults[recommendation.documentId],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recommendation.documentTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _ScoreBadge(score: recommendation.score),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.reasoning,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (recommendation.predictedNewEdges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Predicted new connections:',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              for (final edge in recommendation.predictedNewEdges.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '  ${edge.fromConceptName} --${edge.type.name}--> '
                    '${edge.toConceptName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
            if (recommendation.searchSnippet != null &&
                recommendation.searchSnippet!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                recommendation.searchSnippet!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _IngestAction(
              recommendation: recommendation,
              result: ingestResult,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the ingest button, loading state, evaluation result, or error.
class _IngestAction extends ConsumerWidget {
  const _IngestAction({required this.recommendation, this.result});

  final Recommendation recommendation;
  final RecommendationIngestResult? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = result?.status ?? RecommendationIngestStatus.idle;

    return switch (status) {
      RecommendationIngestStatus.idle => FilledButton.tonal(
        onPressed: () {
          ref
              .read(recommendationProvider.notifier)
              .ingestRecommendation(recommendation);
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, size: 18),
            SizedBox(width: 8),
            Text('Ingest'),
          ],
        ),
      ),
      RecommendationIngestStatus.ingesting ||
      RecommendationIngestStatus.evaluating => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            status == RecommendationIngestStatus.ingesting
                ? 'Ingesting...'
                : 'Evaluating...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      RecommendationIngestStatus.completed => Row(
        children: [
          if (result?.evaluation case final eval?)
            Expanded(child: _EvaluationBadge(evaluation: eval)),
          if (result != null && result!.ingestedConceptIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(glowNodeIdsProvider.notifier).state =
                      result!.ingestedConceptIds;
                  // Pop back to the navigation shell root.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  // Navigate to Dashboard tab (index 1).
                  navigationShellKey.currentState?.navigateToTab(1);
                },
                icon: const Icon(Icons.hub, size: 16),
                label: const Text('View in Graph'),
              ),
            ),
        ],
      ),
      RecommendationIngestStatus.error => Row(
        children: [
          Expanded(
            child: Text(
              result?.errorMessage ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              ref
                  .read(recommendationProvider.notifier)
                  .ingestRecommendation(recommendation);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    };
  }
}

/// Displays evaluation accuracy after a successful ingest.
class _EvaluationBadge extends StatelessWidget {
  const _EvaluationBadge({required this.evaluation});

  final RecommendationEvaluationResult evaluation;

  @override
  Widget build(BuildContext context) {
    final color = switch (evaluation.accuracy) {
      final a? when a >= 0.75 => Colors.green,
      final a? when a >= 0.5 => Colors.amber,
      _ => Colors.grey,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '${evaluation.matchedCount}/${evaluation.totalPredicted} edges matched',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score > 0.7
        ? Colors.green
        : score > 0.4
            ? Colors.amber
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(score * 100).toInt()}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyGapsMessage extends StatelessWidget {
  const _EmptyGapsMessage();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
            SizedBox(height: 8),
            Text(
              'No knowledge gaps detected',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Your knowledge graph is well-connected. Keep learning!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecommendationsMessage extends StatelessWidget {
  const _EmptyRecommendationsMessage();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No matching documents found',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Your wiki may not have content that bridges these gaps yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanPrompt extends ConsumerWidget {
  const _ScanPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.explore_outlined, size: 48, color: Colors.blue),
            const SizedBox(height: 8),
            const Text(
              'Ready to explore',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap Scan to search your wiki for documents that could '
              'fill these gaps.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(recommendationProvider.notifier)
                    .findRecommendations();
              },
              icon: const Icon(Icons.search),
              label: const Text('Scan'),
            ),
          ],
        ),
      ),
    );
  }
}
