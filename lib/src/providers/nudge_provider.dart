import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nudge.dart';
import 'friends_provider.dart';

/// Watches incoming nudges for the current user.
final nudgeProvider =
    AsyncNotifierProvider<NudgeNotifier, List<Nudge>>(NudgeNotifier.new);

class NudgeNotifier extends AsyncNotifier<List<Nudge>> {
  @override
  Future<List<Nudge>> build() async {
    final socialRepo = ref.watch(socialRepositoryProvider);
    if (socialRepo == null) return [];

    final subscription = socialRepo.watchIncomingNudges().listen((nudges) {
      state = AsyncData(nudges);
    });

    ref.onDispose(subscription.cancel);

    return await socialRepo.watchIncomingNudges().first;
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
