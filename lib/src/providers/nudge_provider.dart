import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nudge.dart';
import 'social_repository_provider.dart';

/// Watches incoming nudges for the current user.
final nudgeProvider =
    StreamNotifierProvider<NudgeNotifier, List<Nudge>>(NudgeNotifier.new);

class NudgeNotifier extends StreamNotifier<List<Nudge>> {
  @override
  Stream<List<Nudge>> build() {
    final socialRepo = ref.watch(socialRepositoryProvider);
    if (socialRepo == null) return const Stream.empty();
    return socialRepo.watchIncomingNudges();
  }

  Future<void> sendNudge(Nudge nudge) async {
    final socialRepo = ref.read(socialRepositoryProvider);
    if (socialRepo == null) return;
    await socialRepo.sendNudge(nudge);
  }

  Future<void> markSeen(String nudgeId) async {
    final socialRepo = ref.read(socialRepositoryProvider);
    if (socialRepo == null) return;
    await socialRepo.markNudgeSeen(nudgeId);
  }
}
