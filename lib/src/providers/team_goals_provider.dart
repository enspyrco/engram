import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/team_goal.dart';
import 'auth_provider.dart';
import 'clock_provider.dart';
import 'guardian_provider.dart';

const _uuid = Uuid();

/// Manages team goals — streams active goals from Firestore and provides
/// CRUD operations for creating goals and recording contributions.
final teamGoalsProvider =
    AsyncNotifierProvider<TeamGoalsNotifier, List<TeamGoal>>(
  TeamGoalsNotifier.new,
);

class TeamGoalsNotifier extends AsyncNotifier<List<TeamGoal>> {
  @override
  Future<List<TeamGoal>> build() async {
    final teamRepo = ref.watch(teamRepositoryProvider);
    if (teamRepo == null) return [];

    final subscription = teamRepo.watchActiveGoals().listen((goals) {
      state = AsyncData(goals);
    });
    ref.onDispose(subscription.cancel);

    return await teamRepo.watchActiveGoals().first;
  }

  /// Create a new team goal.
  Future<void> createGoal({
    required String title,
    required String description,
    required GoalType type,
    String? targetCluster,
    required double targetValue,
    required String deadline,
  }) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (teamRepo == null || user == null) return;

    final now = ref.read(clockProvider)();
    final goal = TeamGoal(
      id: 'goal_${_uuid.v4()}',
      title: title,
      description: description,
      type: type,
      targetCluster: targetCluster,
      targetValue: targetValue,
      createdAt: now.toIso8601String(),
      deadline: deadline,
      createdByUid: user.uid,
    );

    await teamRepo.writeTeamGoal(goal);
  }

  /// Record a contribution toward a goal.
  Future<void> recordContribution(String goalId, double amount) async {
    final teamRepo = ref.read(teamRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (teamRepo == null || user == null) return;

    await teamRepo.updateGoalContribution(goalId, user.uid, amount);

    // Check if goal is now complete
    final goals = state.valueOrNull ?? [];
    final goal = goals.where((g) => g.id == goalId).firstOrNull;
    if (goal != null) {
      final updatedProgress = goal.totalProgress + amount;
      if (updatedProgress >= goal.targetValue && !goal.isComplete) {
        final now = ref.read(clockProvider)().toIso8601String();
        await teamRepo.completeGoal(goalId, now);

        // Award goal points to all contributors
        for (final uid in goal.contributions.keys) {
          await teamRepo.addGloryPoints(uid, goalPoints: 5);
        }
        // Bonus for the person who pushed it over
        await teamRepo.addGloryPoints(user.uid, goalPoints: 3);
      }
    }
  }
}
