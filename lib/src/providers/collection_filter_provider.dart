import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'knowledge_graph_provider.dart';

/// Distinct collections derived from document metadata in the knowledge graph.
final availableCollectionsProvider =
    Provider<List<({String id, String name})>>((ref) {
  final graph = ref.watch(knowledgeGraphProvider).valueOrNull;
  if (graph == null) return const [];

  final seen = <String>{};
  final collections = <({String id, String name})>[];
  for (final meta in graph.documentMetadata) {
    final id = meta.collectionId;
    final name = meta.collectionName;
    if (id != null && name != null && seen.add(id)) {
      collections.add((id: id, name: name));
    }
  }
  collections.sort((a, b) => a.name.compareTo(b.name));
  return collections;
});

/// Currently selected collection for quiz filtering. `null` means all.
final selectedCollectionIdProvider = StateProvider<String?>((ref) => null);
