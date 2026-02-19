import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'knowledge_graph_provider.dart';
import 'service_providers.dart';

/// State for the document diff viewer.
sealed class DocumentDiffState {
  const DocumentDiffState();
}

class DocumentDiffIdle extends DocumentDiffState {
  const DocumentDiffIdle();
}

class DocumentDiffLoading extends DocumentDiffState {
  const DocumentDiffLoading();
}

@immutable
class DocumentDiffLoaded extends DocumentDiffState {
  const DocumentDiffLoaded({
    required this.oldText,
    required this.newText,
    required this.ingestedAt,
  });

  /// The document text at the time of last ingestion.
  final String oldText;

  /// The current document text from the wiki.
  final String newText;

  /// When the document was last ingested.
  final DateTime ingestedAt;
}

class DocumentDiffError extends DocumentDiffState {
  const DocumentDiffError(this.message);
  final String message;
}

final documentDiffProvider =
    NotifierProvider<DocumentDiffNotifier, DocumentDiffState>(
  DocumentDiffNotifier.new,
);

class DocumentDiffNotifier extends Notifier<DocumentDiffState> {
  @override
  DocumentDiffState build() => const DocumentDiffIdle();

  /// Fetch the current document text and compare it against the stored
  /// [ingestedText] from [DocumentMetadata].
  Future<void> fetchDiff({
    required String documentId,
  }) async {
    state = const DocumentDiffLoading();

    try {
      // Look up stored ingested text from the knowledge graph.
      final graph = ref.read(knowledgeGraphProvider).valueOrNull;
      final meta = graph?.documentMetadata
          .where((m) => m.documentId == documentId)
          .firstOrNull;

      if (meta == null) {
        state = const DocumentDiffError('Document metadata not found');
        return;
      }

      if (meta.ingestedText == null) {
        state = const DocumentDiffError(
          'No previous version stored. Re-ingest this document first to '
          'enable diff viewing.',
        );
        return;
      }

      // Fetch current text from Outline.
      final client = ref.read(outlineClientProvider);
      final currentDoc = await client.getDocument(documentId);
      final currentText = currentDoc['text'] as String? ?? '';

      state = DocumentDiffLoaded(
        oldText: meta.ingestedText!,
        newText: currentText,
        ingestedAt: DateTime.parse(meta.ingestedAt),
      );
    } catch (e) {
      state = DocumentDiffError('Diff fetch failed: $e');
    }
  }

  void reset() {
    state = const DocumentDiffIdle();
  }
}
