import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crdt/firestore_sync_transport.dart';
import '../models/crdt_sync_state.dart';
import '../storage/drift/drift_graph_repository.dart';
import 'auth_provider.dart';
import 'clock_provider.dart';
import 'graph_store_provider.dart';
import 'hlc_provider.dart';
import 'knowledge_graph_provider.dart';

/// Bookmark key for the push position: the max HLC already pushed.
///
/// New with the numbered log, so a device upgrading from the old log has no
/// push bookmark and pushes everything once: the new log starts with every
/// device's whole graph.
const _pushPeerId = 'firestore-sync-log-v2:push';

/// Bookmark key for the pull position: the highest log entry read.
const _pullPeerId = 'firestore-sync-log-v2:pull';

// ---------------------------------------------------------------------------
// Typed DriftGraphRepository provider
// ---------------------------------------------------------------------------

/// Provides the [DriftGraphRepository] directly (not the abstract
/// [GraphRepository]) so CRDT sync can call Drift-specific methods like
/// [getChangeset], [mergeChangeset], [getLastSyncedHlc], etc.
final driftGraphRepositoryProvider = Provider<DriftGraphRepository>((ref) {
  final db = ref.watch(engramDatabaseProvider);
  final hlcManager = ref.watch(hlcManagerProvider);
  final clock = ref.watch(clockProvider);
  return DriftGraphRepository(db: db, hlcManager: hlcManager, clock: clock);
});

// ---------------------------------------------------------------------------
// Firestore sync transport provider
// ---------------------------------------------------------------------------

/// Provides the [FirestoreSyncTransport] for the authenticated user.
///
/// Returns `null` when unauthenticated — CRDT sync requires a user ID
/// for the `users/{uid}/sync_log` path.
final firestoreSyncTransportProvider = Provider<FirestoreSyncTransport?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final firestore = ref.watch(firestoreProvider);
  return FirestoreSyncTransport(firestore: firestore, userId: user.uid);
});

// ---------------------------------------------------------------------------
// CRDT sync notifier
// ---------------------------------------------------------------------------

final crdtSyncProvider = NotifierProvider<CrdtSyncNotifier, CrdtSyncState>(
  CrdtSyncNotifier.new,
);

/// Orchestrates CRDT changeset sync between the local Drift database and
/// the Firestore sync_log.
///
/// **Sync lifecycle:**
/// 1. Push: generate local changeset since last push → write to the log
/// 2. Pull: read entries after the pull bookmark → merge each into Drift
///
/// Uses separate push/pull bookmarks so a failed pull doesn't block
/// future pushes (and vice versa). Guards against overlapping syncs via
/// [CrdtSyncState.isSyncing].
class CrdtSyncNotifier extends Notifier<CrdtSyncState> {
  Timer? _periodicTimer;

  /// Consecutive sync errors for exponential backoff.
  int _consecutiveErrors = 0;

  /// Number of periodic ticks to skip before retrying after errors.
  int _skipTicks = 0;

  @override
  CrdtSyncState build() {
    ref.onDispose(_stopTimer);
    return CrdtSyncState.initial;
  }

  /// Runs a full push + pull sync cycle. No-op if already syncing or if
  /// the transport is unavailable (unauthenticated).
  Future<void> sync() async {
    if (state.isSyncing) return;

    final transport = ref.read(firestoreSyncTransportProvider);
    if (transport == null) return;

    final driftRepo = ref.read(driftGraphRepositoryProvider);
    final nodeId = ref.read(nodeIdRepositoryProvider).nodeId;
    final clock = ref.read(clockProvider);

    var pushedCount = 0;
    var pulledCount = 0;
    var mergedCount = 0;

    try {
      // -- Push --
      state = state.copyWith(phase: CrdtSyncPhase.pushing, errorMessage: '');

      final lastPushHlc = await driftRepo.getLastSyncedHlc(_pushPeerId) ?? '';
      final changeset = await driftRepo.getChangeset(
        modifiedAfter: lastPushHlc,
      );

      if (!changeset.isEmpty) {
        await transport.pushChangeset(changeset: changeset, nodeId: nodeId);
        pushedCount = changeset.recordCount;

        // Update push bookmark to the max HLC we just pushed.
        await driftRepo.updateLastSyncedHlc(_pushPeerId, changeset.maxHlc);
      }

      // -- Pull --
      state = state.copyWith(phase: CrdtSyncPhase.pulling);

      final pulledSeq = await driftRepo.getSyncedSeq(_pullPeerId);
      final pulled = await transport.pullChangesets(afterSeq: pulledSeq);
      pulledCount = pulled.changesets.length;

      // -- Merge --
      if (pulled.changesets.isNotEmpty) {
        state = state.copyWith(phase: CrdtSyncPhase.merging);
        for (final changeset in pulled.changesets) {
          mergedCount += await driftRepo.mergeChangeset(changeset);
        }
        // Refresh the in-memory graph so merged remote data is visible.
        ref.invalidate(knowledgeGraphProvider);
      }

      if (pulled.lastSeq > pulledSeq) {
        await driftRepo.updateSyncedSeq(_pullPeerId, pulled.lastSeq);
      }

      // Nothing is cleaned up: the log is the cloud copy a new or restored
      // device replays, and tombstones are what make a device's older live
      // copy lose when it finally syncs.

      _consecutiveErrors = 0;
      _skipTicks = 0;

      // Unreadable entries don't stop sync, but they hold the bookmark, so
      // say so rather than look healthy.
      final unreadable =
          pulled.unreadable.isEmpty
              ? ''
              : 'unreadable sync log entries: ${pulled.unreadable.join(', ')}';
      if (unreadable.isNotEmpty) debugPrint('[CrdtSync] $unreadable');

      state = CrdtSyncState(
        phase: CrdtSyncPhase.idle,
        lastSyncedAt: clock(),
        pushedCount: pushedCount,
        pulledCount: pulledCount,
        mergedCount: mergedCount,
        errorMessage: unreadable,
      );
    } catch (e) {
      debugPrint('[CrdtSync] sync failed: $e');
      _consecutiveErrors++;
      _skipTicks = min(1 << _consecutiveErrors, 6);
      state = state.copyWith(phase: CrdtSyncPhase.error, errorMessage: '$e');
    }
  }

  /// Starts periodic sync with the given [interval] (default 5 minutes).
  ///
  /// Triggers an immediate sync, then repeats every [interval]. Calling
  /// this when a timer is already running replaces the existing timer.
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _stopTimer();
    _periodicTimer = Timer.periodic(interval, (_) {
      if (_skipTicks > 0) {
        _skipTicks--;
        return;
      }
      sync();
    });
    // Trigger an immediate sync as well.
    sync();
  }

  /// Stops periodic sync. Safe to call when no timer is active.
  void stopSync() {
    _stopTimer();
  }

  void _stopTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
}
