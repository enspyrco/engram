import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard_stats.dart';
import '../../models/sync_status.dart';
import '../../providers/catastrophe_provider.dart';
import '../../providers/collection_filter_provider.dart';
import '../../providers/dashboard_stats_provider.dart';
import '../../providers/document_diff_provider.dart';
import '../../providers/filtered_graph_provider.dart';
import '../../providers/graph_structure_provider.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/network_health_provider.dart';
import '../../providers/sync_provider.dart';
import '../graph/force_directed_graph_widget.dart';
import '../navigation_shell.dart';
import '../widgets/document_diff_sheet.dart';
import '../widgets/mastery_bar.dart';
import '../widgets/network_health_indicator.dart';
import '../widgets/repair_mission_card.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      knowledgeGraphProvider.select((av) => av.isLoading),
    );
    final error = ref.watch(
      knowledgeGraphProvider.select((av) => av.error),
    );
    final structure = ref.watch(graphStructureProvider);
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
            _SyncBanner(syncStatus: syncStatus),
          if (syncStatus.newCollections.isNotEmpty)
            _NewCollectionsBanner(
              collections: syncStatus.newCollections,
            ),
          Expanded(
            child: isLoading
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
      tooltip: syncStatus.phase == SyncPhase.error
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
    // Only changed docs (those with ingestedAt) can show a diff.
    final changedDocs = syncStatus.staleDocuments
        .where((d) => d.containsKey('ingestedAt'))
        .toList();

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
    List<Map<String, String>> changedDocs,
  ) {
    if (changedDocs.length == 1) {
      _openDiffSheet(context, ref, changedDocs.first);
    } else {
      _openDocPicker(context, ref, changedDocs);
    }
  }

  void _openDiffSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> doc,
  ) {
    ref.read(documentDiffProvider.notifier).fetchDiff(
          documentId: doc['id']!,
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) =>
            DocumentDiffSheet(scrollController: scrollController),
      ),
    ).whenComplete(() {
      ref.read(documentDiffProvider.notifier).reset();
    });
  }

  void _openDocPicker(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, String>> changedDocs,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
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
              title: Text(doc['title'] ?? doc['id']!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                _openDiffSheet(context, ref, doc);
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

/// Full-screen graph with collection chips and compact stats overlay.
class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(filteredGraphProvider);
    final stats = ref.watch(filteredStatsProvider);

    return Stack(
      children: [
        // Full-screen animated graph — LayoutBuilder passes actual screen
        // dimensions so the force-directed layout fills available space.
        Positioned.fill(
          child: graph != null
              ? LayoutBuilder(
                  builder: (context, constraints) =>
                      ForceDirectedGraphWidget(
                    graph: graph,
                    layoutWidth: constraints.maxWidth,
                    layoutHeight: constraints.maxHeight,
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
        // Compact stats bar at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _CompactStatsBar(
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
              onSelected: (_) =>
                  ref.read(selectedCollectionIdProvider.notifier).state = null,
            ),
            const SizedBox(width: 8),
            for (final col in collections) ...[
              FilterChip(
                label: Text(col.name),
                selected: selected == col.id,
                onSelected: (_) =>
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

/// Semi-transparent stats bar at the bottom of the dashboard.
///
/// Shows filtered stats (matching the selected collection). The info button
/// opens a bottom sheet with full global stats from [dashboardStatsProvider].
class _CompactStatsBar extends StatelessWidget {
  const _CompactStatsBar({
    required this.conceptCount,
    required this.masteredCount,
    required this.dueCount,
  });

  final int conceptCount;
  final int masteredCount;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _statChip(Icons.lightbulb, '$conceptCount'),
          const SizedBox(width: 16),
          _statChip(Icons.check_circle, '$masteredCount'),
          const SizedBox(width: 16),
          _statChip(Icons.schedule, '$dueCount'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: 'Full stats',
            onPressed: () => _showStatsSheet(context),
          ),
        ],
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

  void _showStatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _StatsBottomSheet(),
    );
  }
}

/// Bottom sheet with the full stats, mastery bar, health, and graph status.
class _StatsBottomSheet extends ConsumerWidget {
  const _StatsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final health = ref.watch(networkHealthProvider);
    final catastrophe = ref.watch(catastropheProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
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
            const SizedBox(height: 16),
            _GraphStatusCard(stats: stats),
          ],
        );
      },
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
