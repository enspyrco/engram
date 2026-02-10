import 'package:engram/src/models/team_goal.dart';
import 'package:test/test.dart';

void main() {
  group('TeamGoal', () {
    test('fromJson/toJson round-trip', () {
      const goal = TeamGoal(
        id: 'goal_1',
        title: 'Master CI/CD',
        description: 'Get all CI/CD concepts to 80% mastery',
        type: GoalType.clusterMastery,
        targetCluster: 'CI/CD',
        targetValue: 0.8,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
        contributions: {'user1': 0.3, 'user2': 0.2},
      );

      final json = goal.toJson();
      final restored = TeamGoal.fromJson(json);

      expect(restored.id, 'goal_1');
      expect(restored.title, 'Master CI/CD');
      expect(restored.type, GoalType.clusterMastery);
      expect(restored.targetCluster, 'CI/CD');
      expect(restored.targetValue, 0.8);
      expect(restored.createdByUid, 'user1');
      expect(restored.contributions, {'user1': 0.3, 'user2': 0.2});
      expect(restored.completedAt, isNull);
    });

    test('fromJson handles missing optional fields', () {
      final goal = TeamGoal.fromJson(const {
        'id': 'g1',
        'title': 'Test',
        'description': 'desc',
        'type': 'healthTarget',
        'targetValue': 0.9,
        'createdAt': '2025-06-01T00:00:00.000Z',
        'deadline': '2025-06-08T00:00:00.000Z',
        'createdByUid': 'user1',
      });

      expect(goal.targetCluster, isNull);
      expect(goal.contributions, isEmpty);
      expect(goal.completedAt, isNull);
      expect(goal.type, GoalType.healthTarget);
    });

    test('totalProgress sums contributions', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.healthTarget,
        targetValue: 1.0,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
        contributions: {'user1': 0.3, 'user2': 0.5},
      );

      expect(goal.totalProgress, closeTo(0.8, 0.001));
    });

    test('progressFraction is clamped to 1.0', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.healthTarget,
        targetValue: 0.5,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
        contributions: {'user1': 0.6},
      );

      expect(goal.progressFraction, 1.0);
    });

    test('progressFraction is zero when no contributions', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.healthTarget,
        targetValue: 0.5,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
      );

      expect(goal.progressFraction, 0.0);
    });

    test('withContribution adds to existing contribution', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.streakTarget,
        targetValue: 1.0,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
        contributions: {'user1': 0.3},
      );

      final updated = goal.withContribution('user1', 0.2);
      expect(updated.contributions['user1'], closeTo(0.5, 0.001));

      // Original unchanged
      expect(goal.contributions['user1'], 0.3);
    });

    test('withContribution adds new contributor', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.healthTarget,
        targetValue: 1.0,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
      );

      final updated = goal.withContribution('user2', 0.5);
      expect(updated.contributions['user2'], 0.5);
    });

    test('withCompleted sets completedAt', () {
      const goal = TeamGoal(
        id: 'g1',
        title: 'Test',
        description: '',
        type: GoalType.healthTarget,
        targetValue: 1.0,
        createdAt: '2025-06-01T00:00:00.000Z',
        deadline: '2025-06-08T00:00:00.000Z',
        createdByUid: 'user1',
      );

      final completed = goal.withCompleted('2025-06-05T12:00:00.000Z');
      expect(completed.isComplete, isTrue);
      expect(completed.completedAt, '2025-06-05T12:00:00.000Z');
      expect(goal.isComplete, isFalse);
    });

    test('GoalType enum serialization', () {
      for (final type in GoalType.values) {
        final goal = TeamGoal(
          id: 'g1',
          title: 'Test',
          description: '',
          type: type,
          targetValue: 1.0,
          createdAt: '2025-06-01T00:00:00.000Z',
          deadline: '2025-06-08T00:00:00.000Z',
          createdByUid: 'user1',
        );
        final json = goal.toJson();
        final restored = TeamGoal.fromJson(json);
        expect(restored.type, type);
      }
    });
  });
}
