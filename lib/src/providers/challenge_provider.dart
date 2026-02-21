import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge.dart';
import 'social_repository_provider.dart';

/// Watches incoming challenges for the current user.
final challengeProvider =
    StreamNotifierProvider<ChallengeNotifier, List<Challenge>>(
  ChallengeNotifier.new,
);

class ChallengeNotifier extends StreamNotifier<List<Challenge>> {
  @override
  Stream<List<Challenge>> build() {
    final socialRepo = ref.watch(socialRepositoryProvider);
    if (socialRepo == null) return const Stream.empty();
    return socialRepo.watchIncomingChallenges();
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
        challengeId, ChallengeStatus.accepted);
  }

  Future<void> declineChallenge(String challengeId) async {
    final socialRepo = ref.read(socialRepositoryProvider);
    if (socialRepo == null) return;
    await socialRepo.updateChallengeStatus(
        challengeId, ChallengeStatus.declined);
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
