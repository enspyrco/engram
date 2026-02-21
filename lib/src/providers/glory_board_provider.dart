import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/glory_entry.dart';
import 'guardian_provider.dart';

/// Streams the glory board leaderboard from Firestore, sorted by total points.
final gloryBoardProvider =
    AsyncNotifierProvider<GloryBoardNotifier, List<GloryEntry>>(
      GloryBoardNotifier.new,
    );

class GloryBoardNotifier extends AsyncNotifier<List<GloryEntry>> {
  @override
  Future<List<GloryEntry>> build() async {
    final teamRepo = ref.watch(teamRepositoryProvider);
    if (teamRepo == null) return [];

    final subscription = teamRepo.watchGloryBoard().listen((entries) {
      final sorted = List<GloryEntry>.of(entries)
        ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
      state = AsyncData(sorted);
    });
    ref.onDispose(subscription.cancel);

    final initial = await teamRepo.watchGloryBoard().first;
    return List<GloryEntry>.of(initial)
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
  }

  /// Ensure a glory entry exists for a user (called on first contribution).
  Future<void> ensureEntry({
    required String uid,
    required String displayName,
    String? photoUrl,
  }) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    if (teamRepo == null) return;

    final existing = await teamRepo.watchGloryEntry(uid).first;
    if (existing != null) return;

    await teamRepo.writeGloryEntry(
      GloryEntry(uid: uid, displayName: displayName, photoUrl: photoUrl),
    );
  }
}
