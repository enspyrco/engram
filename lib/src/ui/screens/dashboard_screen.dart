import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard_stats.dart';
import '../../models/sync_status.dart';
import '../../providers/catastrophe_provider.dart';
import '../../providers/dashboard_stats_provider.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/network_health_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/team_graph_provider.dart';
import '../navigation_shell.dart';
import '../widgets/mastery_bar.dart';
import '../widgets/mind_map.dart';
import '../widgets/network_health_indicator.dart';
import '../widgets/repair_mission_card.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graphAsync = ref.watch(knowledgeGraphProvider);
    final syncStatus = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          _SyncIconButton(syncStatus: syncStatus),
        ],
      ),
      body: Column(
        children: [
          if (syncStatus.phase == SyncPhase.updatesAvailable &&
              syncStatus.staleDocumentCount > 0)
            _SyncBanner(staleCount: syncStatus.staleDocumentCount),
          if (syncStatus.newCollections.isNotEmpty)
            _NewCollectionsBanner(
              collections: syncStatus.newCollections,
            ),
          Expanded(
            child: graphAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (graph) {
                if (graph.concepts.isEmpty) {
                  return const _EmptyState();
                }
                return _DashboardContent();
              },
            ),
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
      tooltip: syncStatus.phase == SyncPhase.error
          ? syncStatus.errorMessage
          : 'Check for updates',
      onPressed: () => ref.read(syncProvider.notifier).checkForUpdates(),
    );
  }
}

class _SyncBanner extends ConsumerWidget {
  const _SyncBanner({required this.staleCount});

  final int staleCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return MaterialBanner(
      content: Text(
        '$staleCount document${staleCount == 1 ? '' : 's'} updated in wiki',
      ),
      leading: Icon(Icons.sync, color: theme.colorScheme.primary),
      actions: [
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
}

class _NewCollectionsBanner extends ConsumerWidget {
  const _NewCollectionsBanner({required this.collections});

  final List<Map<String, String>> collections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final names = collections.map((c) => c['name']!).toList();
    final label = names.length == 1
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
          onPressed: () => ref.read(syncProvider.notifier).dismissNewCollections(),
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
          Icon(Icons.school_outlined, size: 64, color: theme.colorScheme.primary),
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

class _DashboardContent extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  bool _showTeam = false;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
    final health = ref.watch(networkHealthProvider);
    final catastrophe = ref.watch(catastropheProvider);

    return Column(
      children: [
        // Scrollable stats section
        SizedBox(
          height: 280,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              const SizedBox(height: 16),
              _GraphStatusCard(stats: stats),
            ],
          ),
        ),
        // Team mode toggle + mind map
        if (graph != null && graph.concepts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.people, size: 16),
                const SizedBox(width: 4),
                const Text('Team', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Switch(
                  value: _showTeam,
                  onChanged: (v) => setState(() => _showTeam = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: MindMap(
              graph: graph,
              teamNodes: _showTeam ? ref.watch(teamGraphProvider) : const [],
              healthTier: health.tier,
            ),
          ),
        ],
      ],
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
                  Icon(Icons.warning_amber,
                      color: Colors.orange.shade700, size: 18),
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
