import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import 'stale_document.dart';

enum SyncPhase { idle, checking, updatesAvailable, syncing, upToDate, error }

@immutable
class SyncStatus {
  SyncStatus({
    this.phase = SyncPhase.idle,
    this.staleDocumentCount = 0,
    List<String> staleCollectionIds = const [],
    List<StaleDocument> staleDocuments = const [],
    List<Map<String, String>> newCollections = const [],
    this.errorMessage = '',
  }) : staleCollectionIds = IList(staleCollectionIds),
       staleDocuments = IList(staleDocuments),
       newCollections = IList(newCollections);

  const SyncStatus._({
    this.phase = SyncPhase.idle,
    this.staleDocumentCount = 0,
    this.staleCollectionIds = const IListConst([]),
    this.staleDocuments = const IListConst([]),
    this.newCollections = const IListConst([]),
    this.errorMessage = '',
  });

  static const empty = SyncStatus._();

  final SyncPhase phase;
  final int staleDocumentCount;
  final IList<String> staleCollectionIds;

  /// Individual stale documents with enough info to show diffs.
  /// [StaleDocument.ingestedAt] is absent for new documents that have never
  /// been ingested.
  final IList<StaleDocument> staleDocuments;

  /// Collections found in Outline that haven't been ingested yet.
  /// Each entry is a map with 'id' and 'name' keys.
  final IList<Map<String, String>> newCollections;
  final String errorMessage;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? staleDocumentCount,
    IList<String>? staleCollectionIds,
    IList<StaleDocument>? staleDocuments,
    IList<Map<String, String>>? newCollections,
    String? errorMessage,
  }) {
    return SyncStatus._(
      phase: phase ?? this.phase,
      staleDocumentCount: staleDocumentCount ?? this.staleDocumentCount,
      staleCollectionIds: staleCollectionIds ?? this.staleCollectionIds,
      staleDocuments: staleDocuments ?? this.staleDocuments,
      newCollections: newCollections ?? this.newCollections,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
