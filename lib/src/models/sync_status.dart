import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

enum SyncPhase { idle, checking, updatesAvailable, syncing, upToDate, error }

@immutable
class SyncStatus {
  SyncStatus({
    this.phase = SyncPhase.idle,
    this.staleDocumentCount = 0,
    List<String> staleCollectionIds = const [],
    List<Map<String, String>> newCollections = const [],
    this.errorMessage = '',
  })  : staleCollectionIds = IList(staleCollectionIds),
        newCollections = IList(newCollections);

  const SyncStatus._({
    this.phase = SyncPhase.idle,
    this.staleDocumentCount = 0,
    this.staleCollectionIds = const IListConst([]),
    this.newCollections = const IListConst([]),
    this.errorMessage = '',
  });

  static const empty = SyncStatus._();

  final SyncPhase phase;
  final int staleDocumentCount;
  final IList<String> staleCollectionIds;

  /// Collections found in Outline that haven't been ingested yet.
  /// Each entry is a map with 'id' and 'name' keys.
  final IList<Map<String, String>> newCollections;
  final String errorMessage;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? staleDocumentCount,
    IList<String>? staleCollectionIds,
    IList<Map<String, String>>? newCollections,
    String? errorMessage,
  }) {
    return SyncStatus._(
      phase: phase ?? this.phase,
      staleDocumentCount: staleDocumentCount ?? this.staleDocumentCount,
      staleCollectionIds: staleCollectionIds ?? this.staleCollectionIds,
      newCollections: newCollections ?? this.newCollections,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
