import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'clock_provider.dart';
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
    required this.revisionDate,
  });

  /// The document text at the revision closest to the last ingestion.
  final String oldText;

  /// The current document text.
  final String newText;

  /// When the matched revision was created.
  final DateTime revisionDate;
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

  /// Fetch the current document and its revision history, then find the
  /// revision closest to [ingestedAt] to use as the "old" text.
  Future<void> fetchDiff({
    required String documentId,
    required String ingestedAt,
  }) async {
    state = const DocumentDiffLoading();

    try {
      final client = ref.read(outlineClientProvider);

      // Fetch current doc and revisions in parallel.
      final docFuture = client.getDocument(documentId);
      final revisionsFuture = client.listRevisions(documentId);
      final (currentDoc, revisions) =
          await (docFuture, revisionsFuture).wait;
      final currentText = currentDoc['text'] as String? ?? '';

      if (revisions.isEmpty) {
        state = DocumentDiffLoaded(
          oldText: '',
          newText: currentText,
          revisionDate:
              DateTime.tryParse(ingestedAt) ?? ref.read(clockProvider)(),
        );
        return;
      }

      final ingestedAtDt = DateTime.parse(ingestedAt);

      // Find the revision closest to but not after ingestedAt.
      Map<String, dynamic>? bestMatch;
      DateTime? bestDate;

      for (final rev in revisions) {
        final createdAt = DateTime.parse(rev['createdAt'] as String);
        if (createdAt.compareTo(ingestedAtDt) <= 0) {
          if (bestDate == null || createdAt.isAfter(bestDate)) {
            bestMatch = rev;
            bestDate = createdAt;
          }
        }
      }

      // Fallback: if all revisions are newer, use the oldest one.
      if (bestMatch == null) {
        DateTime? oldestDate;
        for (final rev in revisions) {
          final createdAt = DateTime.parse(rev['createdAt'] as String);
          if (oldestDate == null || createdAt.isBefore(oldestDate)) {
            bestMatch = rev;
            oldestDate = createdAt;
          }
        }
        bestDate = oldestDate;
      }

      state = DocumentDiffLoaded(
        oldText: bestMatch!['text'] as String? ?? '',
        newText: currentText,
        revisionDate: bestDate!,
      );
    } catch (e) {
      state = DocumentDiffError('Diff fetch failed: $e');
    }
  }

  void reset() {
    state = const DocumentDiffIdle();
  }
}
