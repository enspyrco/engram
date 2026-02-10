import 'package:engram/src/models/team_goal.dart';
import 'package:test/test.dart';

void main() {
  group('TeamGoal computed properties', () {
    test('progressFraction handles zero targetValue', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.healthTarget,
        targetValue: 0.0,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
      );

      expect(goal.progressFraction, 1.0);
    });

    test('isComplete reflects completedAt', () {
      const incomplete = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.healthTarget,
        targetValue: 1.0,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
      );

      expect(incomplete.isComplete, isFalse);

      final complete = incomplete.withCompleted('2025-06-05T00:00:00.000Z');
      expect(complete.isComplete, isTrue);
    });

    test('withContribution is additive for same user', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.clusterMastery,
        targetValue: 1.0,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
        contributions: {'user1': 0.2, 'user2': 0.1},
      );

      final updated = goal.withContribution('user1', 0.3);
      expect(updated.contributions['user1'], closeTo(0.5, 0.001));
      expect(updated.contributions['user2'], 0.1); // unchanged
    });

    test('withCompleted preserves all other fields', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test Goal',
        description: 'A description',
        type: GoalType.streakTarget,
        targetCluster: 'Cluster A',
        targetValue: 0.9,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
        contributions: {'user1': 0.5},
      );

      final completed = goal.withCompleted('2025-06-07T00:00:00.000Z');
      expect(completed.id, goal.id);
      expect(completed.title, goal.title);
      expect(completed.description, goal.description);
      expect(completed.type, goal.type);
      expect(completed.targetCluster, goal.targetCluster);
      expect(completed.targetValue, goal.targetValue);
      expect(completed.createdAt, goal.createdAt);
      expect(completed.deadline, goal.deadline);
      expect(completed.createdByUid, goal.createdByUid);
      expect(completed.contributions, goal.contributions);
      expect(completed.completedAt, '2025-06-07T00:00:00.000Z');
    });
  });
}
