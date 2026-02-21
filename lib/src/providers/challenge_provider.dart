import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge.dart';
import 'social_repository_provider.dart';

/// Watches incoming challenges for the current user.
final challengeProvider =
    AsyncNotifierProvider<ChallengeNotifier, List<Challenge>>(
      ChallengeNotifier.new,
    );

class ChallengeNotifier extends AsyncNotifier<List<Challenge>> {
  @override
  Future<List<Challenge>> build() async {
    final socialRepo = ref.watch(socialRepositoryProvider);
    if (socialRepo == null) return [];

    final subscription = socialRepo.watchIncomingChallenges().listen((
      challenges,
    ) {
      state = AsyncData(challenges);
    });

    ref.onDispose(subscription.cancel);

    return await socialRepo.watchIncomingChallenges().first;
  }

  Future<void> sendChallenge(Challenge challenge) async {
    final socialRepo = ref.read(socialRepositoryProvider);
    if (socialRepo == null) return;
    await socialRepo.sendChallenge(challenge);
  }

  Future<void> acceptChallenge(String challengeId) async {
    final socialRepo = ref.read(socialRepositoryProvider);
    if (socialRepo == null) return;
    await socialRepo.updateChallengeStatus(
      challengeId,
      ChallengeStatus.accepted,
    );
  }

  Future<void> declineChallenge(String challengeId) async {
    final socialRepo = ref.read(socialRepositoryProvider);
    if (socialRepo == null) return;
    await socialRepo.updateChallengeStatus(
      challengeId,
      ChallengeStatus.declined,
    );
  }

  Future<void> completeChallenge(String challengeId, int score) async {
    final socialRepo = ref.read(socialRepositoryProvider);
    if (socialRepo == null) return;
    await socialRepo.updateChallengeStatus(
      challengeId,
      ChallengeStatus.completed,
      score: score,
    );
  }
}
