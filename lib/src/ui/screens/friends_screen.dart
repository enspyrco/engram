import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/challenge.dart';
import '../../models/concept_cluster.dart';
import '../../models/friend.dart';
import '../../models/nudge.dart';
import '../../models/team_goal.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catastrophe_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/glory_board_provider.dart';
import '../../providers/guardian_provider.dart';
import '../../providers/nudge_provider.dart';
import '../../providers/relay_provider.dart';
import '../../providers/storm_provider.dart';
import '../../providers/team_goals_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../widgets/challenge_dialog.dart';
import '../widgets/create_relay_dialog.dart';
import '../widgets/entropy_storm_card.dart';
import '../widgets/friend_card.dart';
import '../widgets/glory_board.dart';
import '../widgets/incoming_challenge_card.dart';
import '../widgets/nudge_card.dart';
import '../widgets/relay_challenge_card.dart';
import '../widgets/team_goal_card.dart';

const _uuid = Uuid();

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Team'),
            Tab(text: 'Glory'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FriendsTab(),
          _TeamTab(),
          _GloryTab(),
        ],
      ),
    );
  }
}

// --- Friends Tab (original content) ---

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final challengesAsync = ref.watch(challengeProvider);
    final nudgesAsync = ref.watch(nudgeProvider);

    return friendsAsync.when(
      data: (friends) => _buildContent(
        context,
        ref,
        friends: friends,
        challenges: challengesAsync.valueOrNull ?? [],
        nudges: nudgesAsync.valueOrNull ?? [],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
                id: 'nudge_${_uuid.v4()}',
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

// --- Team Tab (guardians + goals + missions) ---

class _TeamTab extends ConsumerWidget {
  const _TeamTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardianState = ref.watch(guardianProvider);
    final goalsAsync = ref.watch(teamGoalsProvider);
    final catastropheState = ref.watch(catastropheProvider);
    final relaysAsync = ref.watch(relayProvider);
    final stormAsync = ref.watch(stormProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Guardian assignments
        Text('Guardians', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (guardianState.clusters.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No clusters detected yet. Ingest more concepts to form clusters.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else
          for (final cluster in guardianState.clusters)
            _GuardianClusterCard(
              cluster: cluster,
              isMyGuard: cluster.guardianUid == guardianState.currentUid,
              onVolunteer: () => ref
                  .read(guardianProvider.notifier)
                  .volunteerAsGuardian('cluster_${guardianState.clusters.indexOf(cluster)}'),
              onResign: () => ref
                  .read(guardianProvider.notifier)
                  .resignGuardian('cluster_${guardianState.clusters.indexOf(cluster)}'),
            ),

        const SizedBox(height: 16),

        // Active goals
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Team Goals', style: Theme.of(context).textTheme.titleSmall),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: () => _showCreateGoalDialog(context, ref),
              tooltip: 'Create goal',
            ),
          ],
        ),
        const SizedBox(height: 8),
        goalsAsync.when(
          data: (goals) {
            if (goals.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No active goals. Create one to rally the team!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              );
            }
            return Column(
              children: goals.map((g) => TeamGoalCard(goal: g)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading goals: $e'),
        ),

        const SizedBox(height: 16),

        // Active missions
        Text('Active Missions', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (catastropheState.activeMissions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No active repair missions. The network is holding steady!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else
          for (final mission in catastropheState.activeMissions)
            Card(
              child: ListTile(
                leading: const Icon(Icons.build),
                title: Text('Repair Mission: ${mission.conceptIds.length} concepts'),
                subtitle: LinearProgressIndicator(value: mission.progress),
                trailing: Text('${mission.remaining} left'),
              ),
            ),

        const SizedBox(height: 16),

        // Relay Challenges
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Relay Challenges', style: Theme.of(context).textTheme.titleSmall),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: () => _showCreateRelayDialog(context),
              tooltip: 'Create relay',
            ),
          ],
        ),
        const SizedBox(height: 8),
        relaysAsync.when(
          data: (relays) {
            if (relays.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Create a relay to challenge the team to master a concept chain!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              );
            }
            return Column(
              children: relays
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RelayChallengeCard(
                          relay: r,
                          currentUid: currentUid,
                          onClaimLeg: (legIndex) => ref
                              .read(relayProvider.notifier)
                              .claimLeg(r.id, legIndex),
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading relays: $e'),
        ),

        const SizedBox(height: 16),

        // Entropy Storm
        Text('Entropy Storm', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        stormAsync.when(
          data: (storm) {
            if (storm == null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'No storm scheduled. Brave enough to start one?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _showScheduleStormDialog(context, ref),
                        icon: const Icon(Icons.thunderstorm, size: 16),
                        label: const Text('Schedule Storm'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return EntropyStormCard(
              storm: storm,
              currentUid: currentUid,
              onOptIn: () => ref.read(stormProvider.notifier).optIn(),
              onOptOut: () => ref.read(stormProvider.notifier).optOut(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading storm: $e'),
        ),
      ],
    );
  }

  void _showCreateRelayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const CreateRelayDialog(),
    );
  }

  Future<void> _showScheduleStormDialog(BuildContext context, WidgetRef ref) async {
    // Default: start 24 hours from now
    final defaultStart = DateTime.now().toUtc().add(const Duration(hours: 24));

    final date = await showDatePicker(
      context: context,
      initialDate: defaultStart,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(defaultStart),
    );
    if (time == null) return;

    final startTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();
    await ref.read(stormProvider.notifier).scheduleStorm(startTime);
  }

  void _showCreateGoalDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedType = GoalType.clusterMastery;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Team Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Master all CI/CD concepts',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<GoalType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Goal Type',
                    border: OutlineInputBorder(),
                  ),
                  items: GoalType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.name),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedType = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                final deadline = DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 7))
                    .toIso8601String();
                await ref.read(teamGoalsProvider.notifier).createGoal(
                      title: titleController.text,
                      description: descriptionController.text,
                      type: selectedType,
                      targetValue: 0.8,
                      deadline: deadline,
                    );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianClusterCard extends StatelessWidget {
  const _GuardianClusterCard({
    required this.cluster,
    required this.isMyGuard,
    required this.onVolunteer,
    required this.onResign,
  });

  final ConceptCluster cluster;
  final bool isMyGuard;
  final VoidCallback onVolunteer;
  final VoidCallback onResign;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          cluster.hasGuardian ? Icons.shield : Icons.shield_outlined,
          color: cluster.hasGuardian ? const Color(0xFFFFD700) : null,
        ),
        title: Text(cluster.label),
        subtitle: Text(
          cluster.hasGuardian
              ? (isMyGuard ? 'You are guardian' : 'Has guardian')
              : 'No guardian',
        ),
        trailing: isMyGuard
            ? TextButton(
                onPressed: onResign,
                child: const Text('Resign'),
              )
            : (!cluster.hasGuardian
                ? FilledButton(
                    onPressed: onVolunteer,
                    child: const Text('Volunteer'),
                  )
                : null),
      ),
    );
  }
}

// --- Glory Tab ---

class _GloryTab extends ConsumerWidget {
  const _GloryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gloryAsync = ref.watch(gloryBoardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            "Who's Holding the Line",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: gloryAsync.when(
            data: (entries) => GloryBoard(entries: entries),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}
