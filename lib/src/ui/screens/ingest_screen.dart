import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ingest_state.dart';
import '../../providers/ingest_provider.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/settings_provider.dart';
import '../graph/force_directed_graph_widget.dart';

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
              IngestPhase.idle => _IdleView(onLoad: () =>
                  ref.read(ingestProvider.notifier).loadCollections()),
              IngestPhase.loadingCollections =>
                const Center(child: CircularProgressIndicator()),
              IngestPhase.ready => _CollectionPicker(state: ingest),
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
          Text('API keys not configured', style: theme.textTheme.headlineSmall),
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
          child: Text('Select a collection', style: theme.textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.collections.length,
            itemBuilder: (context, index) {
              final collection = state.collections[index];
              final name = collection['name'] as String? ?? 'Untitled';
              final isSelected = state.selectedCollection?['id'] ==
                  collection['id'];

              return ListTile(
                title: Text(name),
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
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
                      ? () => ref.read(ingestProvider.notifier).startIngestion()
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
    final graph = ref.watch(knowledgeGraphProvider).valueOrNull;

    return Column(
      children: [
        // Live graph — grows as concepts are extracted
        if (graph != null && graph.concepts.isNotEmpty)
          Expanded(child: ForceDirectedGraphWidget(graph: graph))
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
          Text('Ingestion Complete', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${state.extractedCount} extracted, ${state.skippedCount} skipped'),
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
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
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
