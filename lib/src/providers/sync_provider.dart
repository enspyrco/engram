import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stale_document.dart';
import '../models/sync_status.dart';
import 'clock_provider.dart';
import 'knowledge_graph_provider.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

final syncProvider = NotifierProvider<SyncNotifier, SyncStatus>(
  SyncNotifier.new,
);

class SyncNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.empty;

  /// Check all ingested collections for documents whose `updatedAt` timestamp
  /// has changed since we last ingested them, and discover new collections
  /// that haven't been ingested yet.
  Future<void> checkForUpdates() async {
    final config = ref.read(settingsProvider);
    if (!config.isOutlineConfigured) return;

    final graph = ref.read(knowledgeGraphProvider).valueOrNull;
    if (graph == null) return;

    state = state.copyWith(phase: SyncPhase.checking);

    try {
      final client = ref.read(outlineClientProvider);
      final repo = ref.read(settingsRepositoryProvider);
      final ingestedIds = repo.getIngestedCollectionIds();

      // --- Discover new collections ---
      final allCollections = await client.listCollections();
      final ingestedSet = ingestedIds.toSet();
      final newCollections = <Map<String, String>>[];
      for (final col in allCollections) {
        final id = col['id'] as String;
        if (!ingestedSet.contains(id)) {
          newCollections.add({'id': id, 'name': col['name'] as String});
        }
      }

      // --- Check for stale documents in ingested collections ---
      var staleCount = 0;
      final staleCollections = <String>[];
      final staleDocs = <StaleDocument>[];

      if (ingestedIds.isNotEmpty && graph.documentMetadata.isNotEmpty) {
        for (final collectionId in ingestedIds) {
          final docs = await client.listDocuments(collectionId);
          var collectionHasStale = false;

          for (final doc in docs) {
            final docId = doc['id'] as String;
            final docTitle = doc['title'] as String;
            final updatedAt = doc['updatedAt'] as String;

            final existing =
                graph.documentMetadata
                    .where((m) => m.documentId == docId)
                    .firstOrNull;

            // Count as stale if: new document (not yet ingested) OR updated since ingestion
            if (existing == null || existing.updatedAt != updatedAt) {
              staleCount++;
              collectionHasStale = true;
              staleDocs.add(
                StaleDocument(
                  id: docId,
                  title: docTitle,
                  ingestedAt: existing?.ingestedAt.toIso8601String(),
                ),
              );
            }
          }

          if (collectionHasStale) {
            staleCollections.add(collectionId);
          }
        }
      }

      if (staleCount > 0 || newCollections.isNotEmpty) {
        state = state.copyWith(
          phase: SyncPhase.updatesAvailable,
          staleDocumentCount: staleCount,
          staleCollectionIds: IList(staleCollections),
          staleDocuments: IList(staleDocs),
          newCollections: IList(newCollections),
        );
      } else {
        state = state.copyWith(
          phase: SyncPhase.upToDate,
          newCollections: const IListConst([]),
        );
        await repo.setLastSyncTimestamp(
          ref.read(clockProvider)().toIso8601String(),
        );
      }
    } catch (e) {
      state = state.copyWith(
        phase: SyncPhase.error,
        errorMessage: 'Sync check failed: $e',
      );
    }
  }

  /// Re-ingest stale collections. The existing delta-skip logic in
  /// [IngestNotifier] will handle only processing changed docs.
  Future<void> syncStaleDocuments() async {
    if (state.staleCollectionIds.isEmpty) return;

    state = state.copyWith(phase: SyncPhase.syncing);

    try {
      final client = ref.read(outlineClientProvider);
      final extraction = ref.read(extractionServiceProvider);
      final graphNotifier = ref.read(knowledgeGraphProvider.notifier);

      for (final collectionId in state.staleCollectionIds) {
        final documents = await client.listDocuments(collectionId);

        final initialGraph = ref.read(knowledgeGraphProvider).valueOrNull;
        if (initialGraph == null) return;

        var graph = initialGraph;

        for (final doc in documents) {
          final docId = doc['id'] as String;
          final docTitle = doc['title'] as String;
          final updatedAt = doc['updatedAt'] as String;

          // Skip unchanged documents (same delta logic as ingest_provider)
          final existing =
              graph.documentMetadata
                  .where((m) => m.documentId == docId)
                  .firstOrNull;
          if (existing != null && existing.updatedAt == updatedAt) {
            continue;
          }

          // Fetch and re-extract
          final fullDoc = await client.getDocument(docId);
          final content = fullDoc['text'] as String? ?? '';
          if (content.trim().isEmpty) continue;

          final result = await extraction.extract(
            documentTitle: docTitle,
            documentContent: content,
            existingConceptIds: graph.concepts.map((c) => c.id).toList(),
          );

          await graphNotifier.ingestExtraction(
            result,
            documentId: docId,
            documentTitle: docTitle,
            updatedAt: updatedAt,
            documentText: content,
          );

          graph = ref.read(knowledgeGraphProvider).valueOrNull ?? graph;
        }
      }

      final repo = ref.read(settingsRepositoryProvider);
      await repo.setLastSyncTimestamp(
        ref.read(clockProvider)().toIso8601String(),
      );

      state = SyncStatus.empty.copyWith(phase: SyncPhase.upToDate);
    } catch (e) {
      state = state.copyWith(
        phase: SyncPhase.error,
        errorMessage: 'Sync failed: $e',
      );
    }
  }

  /// Dismiss the new collections banner without navigating.
  void dismissNewCollections() {
    state = state.copyWith(newCollections: const IListConst([]));
    // If there are no stale docs either, go back to idle/upToDate
    if (state.staleDocumentCount == 0) {
      state = state.copyWith(phase: SyncPhase.upToDate);
    }
  }

  void reset() {
    state = SyncStatus.empty;
  }
}
