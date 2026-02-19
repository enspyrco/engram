import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ingest_document.dart';
import '../../models/ingest_state.dart';
import '../../models/knowledge_graph.dart';
import '../../models/topic.dart';
import '../../providers/document_diff_provider.dart';
import '../../providers/ingest_provider.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/topic_provider.dart';
import '../graph/force_directed_graph_widget.dart';
import '../widgets/document_diff_sheet.dart';

class IngestScreen extends ConsumerWidget {
  const IngestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(settingsProvider);
    final ingest = ref.watch(ingestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ingest')),
      body: !config.isFullyConfigured
          ? _notConfigured(context)
          : switch (ingest.phase) {
              IngestPhase.idle => _IdleView(
                  onLoad: () =>
                      ref.read(ingestProvider.notifier).loadCollections()),
              IngestPhase.loadingCollections =>
                const Center(child: CircularProgressIndicator()),
              IngestPhase.ready => _CollectionPicker(state: ingest),
              IngestPhase.topicSelection => _TopicSelectionView(state: ingest),
              IngestPhase.configuringTopic =>
                _TopicConfigurator(state: ingest),
              IngestPhase.ingesting => _ProgressView(state: ingest),
              IngestPhase.done => _DoneView(state: ingest),
              IngestPhase.error => _ErrorView(state: ingest),
            },
    );
  }

  Widget _notConfigured(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_off, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('API keys not configured',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Go to Settings to enter your API keys.'),
        ],
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onLoad});
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onLoad,
        icon: const Icon(Icons.cloud_download),
        label: const Text('Load Collections'),
      ),
    );
  }
}

class _TopicSelectionView extends ConsumerWidget {
  const _TopicSelectionView({required this.state});
  final IngestState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final topics = ref.watch(availableTopicsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text('Topics', style: theme.textTheme.titleMedium),
              ),
              FilledButton.icon(
                onPressed: () {
                  ref.read(ingestProvider.notifier).startNewTopic();
                  ref.read(ingestProvider.notifier)
                      .loadDocumentsForAllCollections();
                },
                icon: const Icon(Icons.add),
                label: const Text('New Topic'),
              ),
            ],
          ),
        ),
        if (topics.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.topic_outlined,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('No topics yet',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                      'Create a topic to group documents for ingestion.'),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                return _TopicTile(topic: topic);
              },
            ),
          ),
        // Legacy collection picker button
        if (state.collections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(ingestProvider.notifier).selectCollection(
                      state.collections.first,
                    );
              },
              icon: const Icon(Icons.folder_outlined),
              label: const Text('Single Collection (Legacy)'),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TopicTile extends ConsumerWidget {
  const _TopicTile({required this.topic});
  final Topic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(Icons.topic, color: theme.colorScheme.primary),
      title: Text(topic.name),
      subtitle: Text(
        '${topic.documentIds.length} documents'
        '${topic.lastIngestedAt != null ? ' — last ingested ${_formatDate(topic.lastIngestedAt!)}' : ''}',
      ),
      trailing: FilledButton(
        onPressed: () {
          ref.read(ingestProvider.notifier).selectTopic(topic);
          ref.read(ingestProvider.notifier)
              .loadDocumentsForAllCollections();
        },
        child: const Text('Ingest'),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _TopicConfigurator extends ConsumerStatefulWidget {
  const _TopicConfigurator({required this.state});
  final IngestState state;

  @override
  ConsumerState<_TopicConfigurator> createState() =>
      _TopicConfiguratorState();
}

class _TopicConfiguratorState extends ConsumerState<_TopicConfigurator> {
  late TextEditingController _nameController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.state.topicName);
    _descController =
        TextEditingController(text: widget.state.topicDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingest = ref.watch(ingestProvider);
    final isExisting = ingest.selectedTopic != null;
    final docs = ingest.availableDocuments;
    final selectedIds = ingest.selectedDocumentIds;

    // Group documents by collection
    final collectionGroups = <String, List<IngestDocument>>{};
    for (final doc in docs) {
      collectionGroups.putIfAbsent(doc.collectionName, () => []).add(doc);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Topic name and description
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Topic name',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                ref.read(ingestProvider.notifier).updateTopicName(v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                ref.read(ingestProvider.notifier).updateTopicDescription(v),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${selectedIds.length} documents selected',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const Divider(),
        // Document picker grouped by collection
        Expanded(
          child: docs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    for (final entry in collectionGroups.entries) ...[
                      _CollectionSection(
                        collectionName: entry.key,
                        collectionId: entry.value.first.collectionId,
                        documents: entry.value,
                        selectedIds: selectedIds,
                      ),
                    ],
                  ],
                ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => ref.read(ingestProvider.notifier).reset(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: selectedIds.isNotEmpty &&
                          _nameController.text.isNotEmpty
                      ? () => ref
                          .read(ingestProvider.notifier)
                          .startTopicIngestion()
                      : null,
                  child: Text(isExisting
                      ? 'Update & Ingest'
                      : 'Create & Ingest'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: selectedIds.isNotEmpty &&
                          _nameController.text.isNotEmpty
                      ? () => ref
                          .read(ingestProvider.notifier)
                          .startTopicIngestion(forceReExtract: true)
                      : null,
                  child: const Text('Re-extract All'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionSection extends ConsumerWidget {
  const _CollectionSection({
    required this.collectionName,
    required this.collectionId,
    required this.documents,
    required this.selectedIds,
  });

  final String collectionName;
  final String collectionId;
  final List<IngestDocument> documents;
  final ISet<String> selectedIds;

  void _showDiff(BuildContext context, WidgetRef ref, String documentId) {
    final graph = ref.read(knowledgeGraphProvider).valueOrNull;
    final meta = graph?.documentMetadata
        .where((m) => m.documentId == documentId)
        .firstOrNull;
    if (meta == null) return;

    ref.read(documentDiffProvider.notifier).fetchDiff(
          documentId: documentId,
          ingestedAt: meta.ingestedAt,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allSelected =
        documents.every((d) => selectedIds.contains(d.id));

    return ExpansionTile(
      title: Text(collectionName, style: theme.textTheme.titleSmall),
      subtitle: Text('${documents.length} documents'),
      trailing: TextButton(
        onPressed: () {
          if (allSelected) {
            ref.read(ingestProvider.notifier)
                .deselectAllInCollection(collectionId);
          } else {
            ref.read(ingestProvider.notifier)
                .selectAllInCollection(collectionId);
          }
        },
        child: Text(allSelected ? 'Deselect All' : 'Select All'),
      ),
      initiallyExpanded: true,
      children: [
        for (final doc in documents)
          CheckboxListTile(
            value: selectedIds.contains(doc.id),
            onChanged: (_) => ref
                .read(ingestProvider.notifier)
                .toggleDocument(doc.id),
            title: Text(doc.title),
            subtitle: _StatusChip(
              status: doc.status,
              onViewChanges: doc.status == IngestDocumentStatus.changed
                  ? () => _showDiff(context, ref, doc.id)
                  : null,
            ),
            dense: true,
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.onViewChanges});
  final IngestDocumentStatus status;
  final VoidCallback? onViewChanges;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      IngestDocumentStatus.newDoc => (Colors.blue, 'New'),
      IngestDocumentStatus.changed => (Colors.amber, 'Changed'),
      IngestDocumentStatus.unchanged => (Colors.grey, 'Unchanged'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        if (onViewChanges != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onViewChanges,
            child: Text(
              'View changes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Legacy collection picker — kept for backward compatibility.
class _CollectionPicker extends ConsumerWidget {
  const _CollectionPicker({required this.state});
  final IngestState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Select a collection',
              style: theme.textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.collections.length,
            itemBuilder: (context, index) {
              final collection = state.collections[index];
              final name = collection['name'] as String? ?? 'Untitled';
              final isSelected =
                  state.selectedCollection?['id'] == collection['id'];

              return ListTile(
                title: Text(name),
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                onTap: () => ref
                    .read(ingestProvider.notifier)
                    .selectCollection(collection),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: state.selectedCollection != null
                      ? () =>
                          ref.read(ingestProvider.notifier).startIngestion()
                      : null,
                  child: const Text('Start Ingestion'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: state.selectedCollection != null
                      ? () => ref
                          .read(ingestProvider.notifier)
                          .startIngestion(forceReExtract: true)
                      : null,
                  child: const Text('Re-extract All'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressView extends ConsumerWidget {
  const _ProgressView({required this.state});
  final IngestState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fullGraph = ref.watch(knowledgeGraphProvider).valueOrNull;
    final sessionIds = state.sessionConceptIds;

    // Filter to only show concepts extracted in this session.
    final graph = fullGraph != null && sessionIds.isNotEmpty
        ? KnowledgeGraph(
            concepts: fullGraph.concepts
                .where((c) => sessionIds.contains(c.id))
                .toList(),
            relationships: fullGraph.relationships
                .where((r) =>
                    sessionIds.contains(r.fromConceptId) &&
                    sessionIds.contains(r.toConceptId))
                .toList(),
          )
        : null;

    return Column(
      children: [
        // Topic name if available
        if (state.selectedTopic != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              state.selectedTopic!.name,
              style: theme.textTheme.titleSmall,
            ),
          ),
        // Live graph — grows as concepts are extracted
        if (graph != null && graph.concepts.isNotEmpty)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => ForceDirectedGraphWidget(
                graph: graph,
                layoutWidth: constraints.maxWidth,
                layoutHeight: constraints.maxHeight,
              ),
            ),
          )
        else
          const Expanded(child: SizedBox.shrink()),
        // Progress info at the bottom
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: state.progress),
              const SizedBox(height: 16),
              Text(
                '${state.processedDocuments} / ${state.totalDocuments} documents',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.currentDocumentTitle.isNotEmpty)
                Text(
                  state.currentDocumentTitle,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              if (state.statusMessage.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  state.statusMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${state.extractedCount} extracted, ${state.skippedCount} skipped',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoneView extends ConsumerWidget {
  const _DoneView({required this.state});
  final IngestState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
          const SizedBox(height: 16),
          Text('Ingestion Complete',
              style: theme.textTheme.headlineSmall),
          if (state.selectedTopic != null) ...[
            const SizedBox(height: 8),
            Text(
              state.selectedTopic!.name,
              style: theme.textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 8),
          Text(
              '${state.extractedCount} extracted, ${state.skippedCount} skipped'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => ref.read(ingestProvider.notifier).reset(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.state});
  final IngestState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(state.errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.read(ingestProvider.notifier).reset(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
