import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/challenge.dart';
import '../../models/friend.dart';
import '../../models/nudge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/nudge_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../widgets/challenge_dialog.dart';
import '../widgets/friend_card.dart';
import '../widgets/incoming_challenge_card.dart';
import '../widgets/nudge_card.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final challengesAsync = ref.watch(challengeProvider);
    final nudgesAsync = ref.watch(nudgeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: friendsAsync.when(
        data: (friends) => _buildContent(
          context,
          ref,
          friends: friends,
          challenges: challengesAsync.valueOrNull ?? [],
          nudges: nudgesAsync.valueOrNull ?? [],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref, {
    required List<Friend> friends,
    required List<Challenge> challenges,
    required List<Nudge> nudges,
  }) {
    if (friends.isEmpty && challenges.isEmpty && nudges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No friends yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Friends using the same Outline wiki will appear here automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Incoming challenges
        for (final challenge in challenges)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IncomingChallengeCard(
              challenge: challenge,
              onAccept: () => ref
                  .read(challengeProvider.notifier)
                  .acceptChallenge(challenge.id),
              onDecline: () => ref
                  .read(challengeProvider.notifier)
                  .declineChallenge(challenge.id),
            ),
          ),

        // Incoming nudges
        for (final nudge in nudges)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NudgeCard(
              nudge: nudge,
              onReviewNow: () {
                ref.read(nudgeProvider.notifier).markSeen(nudge.id);
                // Navigate to quiz tab (index 1)
                // The NavigationShell will handle the tab switch
              },
            ),
          ),

        if (challenges.isNotEmpty || nudges.isNotEmpty)
          const Divider(height: 24),

        // Friends list
        for (final friend in friends)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FriendCard(
              friend: friend,
              onChallenge: () => _showChallengeDialog(context, friend),
              onNudge: () => _showNudgeDialog(context, ref, friend),
            ),
          ),
      ],
    );
  }

  void _showChallengeDialog(BuildContext context, Friend friend) {
    showDialog(
      context: context,
      builder: (_) => ChallengeDialog(friend: friend),
    );
  }

  void _showNudgeDialog(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Nudge ${friend.displayName}'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Message (optional)',
            hintText: 'Hey, time to review!',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final user = ref.read(authStateProvider).valueOrNull;
              final profile = ref.read(userProfileProvider).valueOrNull;
              if (user == null) return;

              final nudge = Nudge(
                id: '${user.uid}_${friend.uid}_${DateTime.now().millisecondsSinceEpoch}',
                fromUid: user.uid,
                fromName: profile?.displayName ?? 'Someone',
                toUid: friend.uid,
                conceptName: 'general review',
                message: messageController.text.isEmpty
                    ? null
                    : messageController.text,
                createdAt: DateTime.now().toUtc().toIso8601String(),
              );

              await ref.read(nudgeProvider.notifier).sendNudge(nudge);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
