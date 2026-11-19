import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard_stats.dart';
import '../../models/knowledge_gap.dart';
import '../../models/knowledge_graph.dart';
import '../../models/narration_session.dart';
import '../../models/network_health.dart';
import '../../models/stale_document.dart';
import '../../models/sync_status.dart';
import '../../engine/difficulty_evaluation.dart';
import '../../providers/catastrophe_provider.dart';
import '../../providers/collection_filter_provider.dart';
import '../../providers/dashboard_stats_provider.dart';
import '../../providers/difficulty_evaluation_provider.dart';
import '../../providers/filtered_graph_provider.dart';
import '../../providers/gap_analysis_provider.dart';
import '../../providers/active_concepts_provider.dart';
import '../../providers/glow_node_provider.dart';
import '../../providers/narration_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/narration_service.dart';
import '../widgets/narration_controls.dart';
import '../../providers/graph_structure_provider.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/network_health_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/sync_provider.dart';
import '../graph/force_directed_graph_widget.dart';
import '../navigation_shell.dart';
import '../widgets/document_diff_sheet.dart';
import '../widgets/mastery_bar.dart';
import '../widgets/network_health_indicator.dart';
import '../widgets/repair_mission_card.dart';
import '../widgets/stat_card.dart';
import 'recommendations_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      knowledgeGraphProvider.select((av) => av.isLoading),
    );
    final error = ref.watch(knowledgeGraphProvider.select((av) => av.error));
    final structure = ref.watch(graphStructureProvider);
    final syncStatus = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [_SyncIconButton(syncStatus: syncStatus)],
      ),
      body: Column(
        children: [
          if (syncStatus.phase == SyncPhase.updatesAvailable &&
              syncStatus.staleDocumentCount > 0)
            _SyncBanner(syncStatus: syncStatus),
          if (syncStatus.newCollections.isNotEmpty)
            _NewCollectionsBanner(collections: syncStatus.newCollections),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Center(child: Text('Error: $error'))
                    : structure == null
                    ? const _EmptyState()
                    : const _DashboardContent(),
          ),
        ],
      ),
    );
  }
}

class _SyncIconButton extends ConsumerWidget {
  const _SyncIconButton({required this.syncStatus});

  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (syncStatus.phase == SyncPhase.checking ||
        syncStatus.phase == SyncPhase.syncing) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      icon: Icon(
        syncStatus.phase == SyncPhase.updatesAvailable
            ? Icons.cloud_download
            : syncStatus.phase == SyncPhase.error
            ? Icons.cloud_off
            : Icons.cloud_done,
      ),
      tooltip:
          syncStatus.phase == SyncPhase.error
              ? syncStatus.errorMessage
              : 'Check for updates',
      onPressed: () => ref.read(syncProvider.notifier).checkForUpdates(),
    );
  }
}

class _SyncBanner extends ConsumerWidget {
  const _SyncBanner({required this.syncStatus});

  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final staleCount = syncStatus.staleDocumentCount;
    final changedDocs =
        syncStatus.staleDocuments.where((d) => d.hasBeenIngested).toList();

    return MaterialBanner(
      content: Text(
        '$staleCount document${staleCount == 1 ? '' : 's'} updated in wiki',
      ),
      leading: Icon(Icons.sync, color: theme.colorScheme.primary),
      actions: [
        if (changedDocs.isNotEmpty)
          TextButton(
            onPressed: () => _showChanges(context, ref, changedDocs),
            child: const Text('View changes'),
          ),
        TextButton(
          onPressed: () => ref.read(syncProvider.notifier).syncStaleDocuments(),
          child: const Text('Sync'),
        ),
        TextButton(
          onPressed: () => ref.read(syncProvider.notifier).reset(),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  void _showChanges(
    BuildContext context,
    WidgetRef ref,
    List<StaleDocument> changedDocs,
  ) {
    if (changedDocs.length == 1) {
      DocumentDiffSheet.show(context, ref, documentId: changedDocs.first.id);
    } else {
      _openDocPicker(context, ref, changedDocs);
    }
  }

  void _openDocPicker(
    BuildContext context,
    WidgetRef ref,
    List<StaleDocument> changedDocs,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder:
          (context) => ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Changed documents',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final doc in changedDocs)
                ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(doc.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pop();
                    DocumentDiffSheet.show(context, ref, documentId: doc.id);
                  },
                ),
            ],
          ),
    );
  }
}

class _NewCollectionsBanner extends ConsumerWidget {
  const _NewCollectionsBanner({required this.collections});

  final Iterable<Map<String, String>> collections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final names = collections.map((c) => c['name']!).toList();
    final label =
        names.length == 1
            ? 'New collection: ${names.first}'
            : '${names.length} new collections: ${names.take(3).join(', ')}'
                '${names.length > 3 ? '...' : ''}';

    return MaterialBanner(
      content: Text(label),
      leading: Icon(Icons.library_add, color: theme.colorScheme.tertiary),
      actions: [
        TextButton(
          onPressed: () {
            // Navigate to the Ingest tab
            navigationShellKey.currentState?.navigateToTab(2);
          },
          child: const Text('Learn'),
        ),
        TextButton(
          onPressed:
              () => ref.read(syncProvider.notifier).dismissNewCollections(),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('No knowledge graph yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Configure your API keys in Settings,\nthen ingest a collection to get started.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Full-screen graph with collection chips and compact stats overlay.
class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(filteredGraphProvider);
    final stats = ref.watch(filteredStatsProvider);
    final glowNodeIds = ref.watch(glowNodeIdsProvider);
    final sustainedGlow = ref.watch(activeConceptsProvider);

    return Stack(
      children: [
        // Full-screen animated graph — LayoutBuilder passes actual screen
        // dimensions so the force-directed layout fills available space.
        Positioned.fill(
          child:
              graph != null
                  ? LayoutBuilder(
                    builder:
                        (context, constraints) => ForceDirectedGraphWidget(
                          graph: graph,
                          layoutWidth: constraints.maxWidth,
                          layoutHeight: constraints.maxHeight,
                          glowNodeIds: glowNodeIds,
                          sustainedGlowMap: sustainedGlow,
                          onGlowComplete: () {
                            ref.read(glowNodeIdsProvider.notifier).state =
                                const {};
                          },
                        ),
                  )
                  : const Center(child: Text('No concepts to display')),
        ),
        // Collection filter chips at top
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _CollectionChipBar(),
        ),
        // Narrate button
        if (graph != null && graph.concepts.isNotEmpty)
          Positioned(
            bottom: 52,
            right: 12,
            child: _NarrateButton(graph: graph),
          ),
        // Persistent insights panel at bottom — always-visible summary of the
        // rich feature-set (curiosity gaps, health, due), expandable to the
        // full stats/health/curiosity detail cards.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _InsightsPanel(
            conceptCount: stats.concepts,
            masteredCount: stats.mastered,
            dueCount: stats.due,
          ),
        ),
      ],
    );
  }
}

/// Horizontal scroll of collection filter chips.
class _CollectionChipBar extends ConsumerWidget {
  const _CollectionChipBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(availableCollectionsProvider);
    final selected = ref.watch(selectedCollectionIdProvider);

    if (collections.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected:
                  (_) =>
                      ref.read(selectedCollectionIdProvider.notifier).state =
                          null,
            ),
            const SizedBox(width: 8),
            for (final col in collections) ...[
              FilterChip(
                label: Text(col.name),
                selected: selected == col.id,
                onSelected:
                    (_) =>
                        ref.read(selectedCollectionIdProvider.notifier).state =
                            selected == col.id ? null : col.id,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Persistent, expandable insights panel anchored to the bottom of the
/// dashboard.
///
/// Collapsed (default): an always-visible summary giving information scent for
/// the rich feature-set — curiosity gaps + a Scan action, network-health %,
/// items due, and concept/mastered counts. Previously these features were
/// hidden behind an easily-missed `info_outline` button.
///
/// Expanded: the full detail cards (stats, mastery, health, repair missions,
/// prediction accuracy, curiosity engine, graph status) inline, scrolling
/// within a height-capped region so the graph stays visible behind it.
///
/// The collapsed summary uses filtered stats (matching the selected
/// collection); graph-wide signals (health, gaps) come from their own
/// providers.
class _InsightsPanel extends ConsumerStatefulWidget {
  const _InsightsPanel({
    required this.conceptCount,
    required this.masteredCount,
    required this.dueCount,
  });

  final int conceptCount;
  final int masteredCount;
  final int dueCount;

  @override
  ConsumerState<_InsightsPanel> createState() => _InsightsPanelState();
}

class _InsightsPanelState extends ConsumerState<_InsightsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final health = ref.watch(networkHealthProvider);
    final gaps = ref.watch(gapAnalysisProvider);
    final recState = ref.watch(recommendationProvider);

    return Material(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      elevation: _expanded ? 8 : 0,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CuriositySummaryRow(gaps: gaps, recState: recState),
            _StatsSummaryRow(
              health: health,
              dueCount: widget.dueCount,
              conceptCount: widget.conceptCount,
              masteredCount: widget.masteredCount,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded) const _InsightsDetail(),
          ],
        ),
      ),
    );
  }
}

/// Collapsed row 1: curiosity-engine scent + Scan action + top pick.
class _CuriositySummaryRow extends ConsumerWidget {
  const _CuriositySummaryRow({required this.gaps, required this.recState});

  final List<KnowledgeGap> gaps;
  final RecommendationState recState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final topRec = recState.recommendations.isNotEmpty
        ? recState.recommendations.first
        : null;
    final scanning =
        recState.phase != RecommendationPhase.idle &&
        recState.phase != RecommendationPhase.done &&
        recState.phase != RecommendationPhase.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Icon(Icons.bolt, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              topRec != null
                  ? 'Top pick: ${topRec.documentTitle}'
                  : gaps.isEmpty
                  ? 'Curiosity Engine — no gaps detected'
                  : '${gaps.length} gap${gaps.length == 1 ? '' : 's'} in your '
                      'knowledge graph',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (scanning)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton.icon(
              onPressed: () =>
                  ref.read(recommendationProvider.notifier).findRecommendations(),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Scan'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.explore, size: 18),
            tooltip: 'Explore recommendations',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecommendationsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsed row 2: health %, due count, concept/mastered chips, expand toggle.
class _StatsSummaryRow extends StatelessWidget {
  const _StatsSummaryRow({
    required this.health,
    required this.dueCount,
    required this.conceptCount,
    required this.masteredCount,
    required this.expanded,
    required this.onToggle,
  });

  final NetworkHealth health;
  final int dueCount;
  final int conceptCount;
  final int masteredCount;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final healthColor = _colorForTier(health.tier);
    final healthPct = (health.score * 100).round();

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
        child: Row(
          children: [
            Icon(Icons.favorite, size: 16, color: healthColor),
            const SizedBox(width: 4),
            Text(
              '$healthPct%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: healthColor,
              ),
            ),
            const SizedBox(width: 16),
            _statChip(Icons.schedule, '$dueCount due'),
            const SizedBox(width: 16),
            _statChip(Icons.lightbulb, '$conceptCount'),
            const SizedBox(width: 16),
            _statChip(Icons.check_circle, '$masteredCount'),
            const Spacer(),
            Text(
              expanded ? 'Less' : 'Details',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Icon(
              expanded ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  static Color _colorForTier(HealthTier tier) {
    switch (tier) {
      case HealthTier.healthy:
        return const Color(0xFF4CAF50);
      case HealthTier.brownout:
        return const Color(0xFFFFC107);
      case HealthTier.cascade:
        return const Color(0xFFFF9800);
      case HealthTier.fracture:
        return const Color(0xFFF44336);
      case HealthTier.collapse:
        return const Color(0xFF9E9E9E);
    }
  }
}

/// Expanded detail: the full set of feature cards, scrolling within a
/// height-capped region so the graph remains partly visible behind it.
class _InsightsDetail extends ConsumerWidget {
  const _InsightsDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final health = ref.watch(networkHealthProvider);
    final catastrophe = ref.watch(catastropheProvider);
    final evaluation = ref.watch(difficultyEvaluationProvider);
    final gaps = ref.watch(gapAnalysisProvider);
    final recState = ref.watch(recommendationProvider);
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatCard(
                label: 'Documents',
                value: '${stats.documentCount}',
                icon: Icons.description,
              ),
              StatCard(
                label: 'Concepts',
                value: '${stats.conceptCount}',
                icon: Icons.lightbulb,
              ),
              StatCard(
                label: 'Relationships',
                value: '${stats.relationshipCount}',
                icon: Icons.share,
              ),
              StatCard(
                label: 'Quiz Items',
                value: '${stats.quizItemCount}',
                icon: Icons.quiz,
              ),
            ],
          ),
          const SizedBox(height: 16),
          MasteryBar(
            newCount: stats.newCount,
            learningCount: stats.learningCount,
            masteredCount: stats.masteredCount,
          ),
          const SizedBox(height: 16),
          NetworkHealthIndicator(health: health),
          for (final mission in catastrophe.activeMissions)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RepairMissionCard(mission: mission),
            ),
          if (evaluation.evaluatedCount > 0) ...[
            const SizedBox(height: 16),
            _PredictionAccuracyCard(evaluation: evaluation),
          ],
          // Curiosity Engine is the centerpiece feature — always render it
          // (even with zero gaps) so it is never invisible.
          const SizedBox(height: 16),
          _CuriosityCard(gaps: gaps, recState: recState),
          const SizedBox(height: 16),
          _GraphStatusCard(stats: stats),
        ],
      ),
    );
  }
}

/// Card showing how well Claude's difficulty predictions match FSRS actuals.
class _PredictionAccuracyCard extends StatelessWidget {
  const _PredictionAccuracyCard({required this.evaluation});

  final DifficultyEvaluationResult evaluation;

  @override
  Widget build(BuildContext context) {
    final mae = evaluation.meanAbsoluteError;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prediction Accuracy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _row('Cards evaluated', '${evaluation.evaluatedCount}'),
            if (mae != null) _row('Mean absolute error', mae.toStringAsFixed(1)),
            for (final entry in evaluation.bandAccuracy.entries)
              _row(
                '${entry.key.label} band',
                '${entry.value.correct}/${entry.value.predicted} correct',
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}

/// Card showing detected knowledge gaps with scan/explore actions.
class _CuriosityCard extends ConsumerWidget {
  const _CuriosityCard({required this.gaps, required this.recState});

  final List<KnowledgeGap> gaps;
  final RecommendationState recState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topRec = recState.recommendations.isNotEmpty
        ? recState.recommendations.first
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Curiosity Engine',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${gaps.length} gap${gaps.length == 1 ? '' : 's'} detected '
              'in your knowledge graph',
            ),
            if (topRec != null) ...[
              const SizedBox(height: 8),
              Text(
                'Top pick: "${topRec.documentTitle}" '
                '(${(topRec.score * 100).toInt()}% fit)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (recState.phase == RecommendationPhase.idle ||
                    recState.phase == RecommendationPhase.done ||
                    recState.phase == RecommendationPhase.error)
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(recommendationProvider.notifier)
                          .findRecommendations();
                    },
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Scan'),
                  )
                else
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RecommendationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.explore, size: 18),
                  label: const Text('Explore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphStatusCard extends StatelessWidget {
  const _GraphStatusCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Graph Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _graphRow('Due for review', '${stats.dueCount}'),
            _graphRow('Foundational', '${stats.foundationalCount}'),
            _graphRow('Unlocked', '${stats.unlockedCount}'),
            _graphRow('Locked', '${stats.lockedCount}'),
            if (stats.hasCycles) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Dependency cycle detected'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _graphRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}

/// FAB-style button that triggers narration and shows playback controls.
class _NarrateButton extends ConsumerWidget {
  const _NarrateButton({required this.graph});

  final KnowledgeGraph graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(narrationProvider);
    final isActive = session.phase != NarrationPhase.idle;

    return FloatingActionButton.small(
      heroTag: 'narrate',
      tooltip: isActive ? 'Narration controls' : 'Narrate graph',
      onPressed: () {
        if (isActive) {
          _showControls(context);
        } else {
          _startNarration(context, ref);
        }
      },
      child: Icon(
        isActive ? Icons.graphic_eq : Icons.record_voice_over,
      ),
    );
  }

  void _startNarration(BuildContext context, WidgetRef ref) {
    final config = ref.read(settingsProvider);
    if (!config.isAnthropicConfigured || !config.isElevenLabsConfigured) {
      final missing = <String>[];
      if (!config.isAnthropicConfigured) missing.add('Anthropic');
      if (!config.isElevenLabsConfigured) missing.add('ElevenLabs');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Narration requires ${missing.join(' and ')} API '
            '${missing.length == 1 ? 'key' : 'keys'}. '
            'Configure in Settings.',
          ),
        ),
      );
      return;
    }

    final concepts = graph.concepts
        .map((c) => ConceptSummary(id: c.id, name: c.name))
        .toList();
    final conceptNames = {for (final c in graph.concepts) c.id: c.name};
    final relationships = graph.relationships
        .where(
          (r) =>
              conceptNames.containsKey(r.fromConceptId) &&
              conceptNames.containsKey(r.toConceptId),
        )
        .map(
          (r) => RelationshipSummary(
            fromName: conceptNames[r.fromConceptId]!,
            toName: conceptNames[r.toConceptId]!,
            label: r.label,
          ),
        )
        .toList();

    ref.read(narrationProvider.notifier).generateNarration(
      concepts: concepts,
      relationships: relationships,
    );

    _showControls(context);
  }

  void _showControls(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SizedBox(
        height: 180,
        child: NarrationControls(),
      ),
    );
  }
}
