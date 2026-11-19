import 'package:material_ui/material_ui.dart';

import '../../../models/entropy_storm.dart';
import '../../../models/network_health.dart';
import '../../../models/relay_challenge.dart';
import '../../../models/repair_mission.dart';
import '../../../models/team_goal.dart';
import '../../widgets/entropy_storm_card.dart';
import '../../widgets/fsrs_rating_bar.dart';
import '../../widgets/mastery_bar.dart';
import '../../widgets/network_health_indicator.dart';
import '../../widgets/relay_challenge_card.dart';
import '../../widgets/repair_mission_card.dart';
import '../../widgets/sign_in_button.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/team_goal_card.dart';
import 'lab_test_data.dart';

/// Scrollable catalog of every visual widget in multiple states.
///
/// All data is hardcoded — no providers, no network. Just widget specimens for
/// quick visual verification and hot-reload iteration.
class WidgetLabTab extends StatelessWidget {
  const WidgetLabTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section('MasteryBar'),
        _specimen(
          'All new',
          const MasteryBar(newCount: 20, learningCount: 0, masteredCount: 0),
        ),
        _specimen(
          'All mastered',
          const MasteryBar(newCount: 0, learningCount: 0, masteredCount: 20),
        ),
        _specimen(
          'Balanced mix',
          const MasteryBar(newCount: 5, learningCount: 8, masteredCount: 7),
        ),
        _specimen(
          'Mostly learning',
          const MasteryBar(newCount: 2, learningCount: 15, masteredCount: 3),
        ),

        _section('FsrsRatingBar'),
        _specimen('Rating buttons', FsrsRatingBar(onRate: (_) {})),

        _section('NetworkHealthIndicator'),
        _specimenRow('All 5 tiers', [
          for (final tier in HealthTier.values)
            SizedBox(
              width: 250,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    NetworkHealthIndicator(
                      health: NetworkHealth(
                        score: _scoreForTier(tier),
                        tier: tier,
                        clusterHealth: const {'A': 0.9, 'B': 0.6},
                        atRiskCriticalPaths: tier == HealthTier.healthy ? 0 : 3,
                        totalCriticalPaths: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(tier.name, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
        ]),

        _section('EntropyStormCard'),
        _specimen(
          'Scheduled',
          EntropyStormCard(
            storm: EntropyStorm(
              id: 'storm-1',
              scheduledStart: labNow.add(const Duration(hours: 6)),
              scheduledEnd: labNow.add(const Duration(hours: 54)),
              status: StormStatus.scheduled,
              participantUids: const ['alice', 'bob'],
              createdByUid: 'alice',
            ),
            currentUid: 'alice',
          ),
        ),
        _specimen(
          'Active',
          EntropyStormCard(
            storm: EntropyStorm(
              id: 'storm-2',
              scheduledStart: labNow.subtract(const Duration(hours: 12)),
              scheduledEnd: labNow.add(const Duration(hours: 36)),
              status: StormStatus.active,
              participantUids: const ['alice', 'bob', 'carol'],
              createdByUid: 'alice',
              lowestHealth: 0.62,
            ),
            currentUid: 'bob',
          ),
        ),
        _specimen(
          'Survived',
          EntropyStormCard(
            storm: EntropyStorm(
              id: 'storm-3',
              scheduledStart: labNow.subtract(const Duration(hours: 60)),
              scheduledEnd: labNow.subtract(const Duration(hours: 12)),
              status: StormStatus.survived,
              participantUids: const ['alice', 'bob'],
              createdByUid: 'alice',
              lowestHealth: 0.73,
            ),
            currentUid: 'alice',
          ),
        ),
        _specimen(
          'Failed',
          EntropyStormCard(
            storm: EntropyStorm(
              id: 'storm-4',
              scheduledStart: labNow.subtract(const Duration(hours: 60)),
              scheduledEnd: labNow.subtract(const Duration(hours: 12)),
              status: StormStatus.failed,
              participantUids: const ['alice'],
              createdByUid: 'alice',
              lowestHealth: 0.45,
            ),
            currentUid: 'alice',
          ),
        ),

        _section('TeamGoalCard'),
        _specimen(
          'Cluster mastery — 30%',
          TeamGoalCard(
            goal: TeamGoal(
              id: 'goal-1',
              title: 'Master the Algorithms cluster',
              description: 'Get 80% mastery across all algorithm concepts',
              type: GoalType.clusterMastery,
              targetCluster: 'Algorithms',
              targetValue: 10.0,
              createdAt: labNow.subtract(const Duration(days: 5)),
              deadline: labNow.add(const Duration(days: 9)),
              createdByUid: 'alice',
              contributions: const {'alice': 2.0, 'bob': 1.0},
            ),
          ),
        ),
        _specimen(
          'Health target — 75%',
          TeamGoalCard(
            goal: TeamGoal(
              id: 'goal-2',
              title: 'Reach 90% network health',
              description: 'Bring overall network health above 90%',
              type: GoalType.healthTarget,
              targetValue: 0.9,
              createdAt: labNow.subtract(const Duration(days: 3)),
              deadline: labNow.add(const Duration(days: 4)),
              createdByUid: 'bob',
              contributions: const {'alice': 0.3, 'bob': 0.2, 'carol': 0.175},
            ),
          ),
        ),
        _specimen(
          'Streak target — just started',
          TeamGoalCard(
            goal: TeamGoal(
              id: 'goal-3',
              title: '7-day review streak',
              description: 'Every team member reviews daily for a week',
              type: GoalType.streakTarget,
              targetValue: 7.0,
              createdAt: labNow.subtract(const Duration(days: 1)),
              deadline: labNow.add(const Duration(days: 13)),
              createdByUid: 'carol',
              contributions: const {'carol': 1.0},
            ),
          ),
        ),

        _section('RelayChallengeCard'),
        _specimen(
          'Partial completion',
          RelayChallengeCard(
            relay: RelayChallenge(
              id: 'relay-1',
              title: 'Memory Techniques Chain',
              legs: [
                RelayLeg(
                  conceptId: 'a',
                  conceptName: 'Spaced Repetition',
                  claimedByUid: 'alice',
                  claimedByName: 'Alice',
                  claimedAt: labNow.subtract(const Duration(hours: 20)),
                  completedAt: labNow.subtract(const Duration(hours: 18)),
                ),
                RelayLeg(
                  conceptId: 'b',
                  conceptName: 'Leitner System',
                  claimedByUid: 'bob',
                  claimedByName: 'Bob',
                  claimedAt: labNow.subtract(const Duration(hours: 5)),
                ),
                const RelayLeg(conceptId: 'c', conceptName: 'Active Recall'),
                const RelayLeg(conceptId: 'd', conceptName: 'FSRS Algorithm'),
              ],
              createdAt: labNow.subtract(const Duration(days: 2)),
              createdByUid: 'alice',
            ),
            currentUid: 'carol',
          ),
        ),
        _specimen(
          'All complete',
          RelayChallengeCard(
            relay: RelayChallenge(
              id: 'relay-2',
              title: 'Encoding Strategies',
              legs: [
                RelayLeg(
                  conceptId: 'e',
                  conceptName: 'Forgetting Curve',
                  claimedByUid: 'alice',
                  claimedByName: 'Alice',
                  claimedAt: labNow.subtract(const Duration(hours: 48)),
                  completedAt: labNow.subtract(const Duration(hours: 46)),
                ),
                RelayLeg(
                  conceptId: 'f',
                  conceptName: 'Memory Palace',
                  claimedByUid: 'bob',
                  claimedByName: 'Bob',
                  claimedAt: labNow.subtract(const Duration(hours: 24)),
                  completedAt: labNow.subtract(const Duration(hours: 22)),
                ),
              ],
              createdAt: labNow.subtract(const Duration(days: 3)),
              createdByUid: 'bob',
              completedAt: labNow.subtract(const Duration(hours: 22)),
            ),
            currentUid: 'alice',
          ),
        ),

        _section('RepairMissionCard'),
        _specimen(
          'Low progress',
          RepairMissionCard(
            mission: RepairMission(
              id: 'mission-1',
              conceptIds: const ['a', 'b', 'c', 'd', 'e'],
              reviewedConceptIds: const ['a'],
              createdAt: labNow.subtract(const Duration(hours: 6)),
            ),
          ),
        ),
        _specimen(
          'Mid progress',
          RepairMissionCard(
            mission: RepairMission(
              id: 'mission-2',
              conceptIds: const ['a', 'b', 'c', 'd'],
              reviewedConceptIds: const ['a', 'b'],
              createdAt: labNow.subtract(const Duration(hours: 12)),
            ),
          ),
        ),
        _specimen(
          'High progress',
          RepairMissionCard(
            mission: RepairMission(
              id: 'mission-3',
              conceptIds: const ['a', 'b', 'c'],
              reviewedConceptIds: const ['a', 'b', 'c'],
              createdAt: labNow.subtract(const Duration(hours: 24)),
              completedAt: labNow.subtract(const Duration(hours: 1)),
            ),
          ),
        ),

        _section('StatCard'),
        _specimenRow('With and without icons', [
          const StatCard(label: 'Cards Due', value: '12', icon: Icons.schedule),
          const StatCard(
            label: 'Mastered',
            value: '47',
            icon: Icons.check_circle,
          ),
          const StatCard(label: 'Streak', value: '5 days'),
          const StatCard(label: 'Health', value: '87%'),
        ]),

        _section('SignInButton'),
        _specimen(
          'Apple branded',
          SignInButton(
            label: 'Continue with Apple',
            icon: const Icon(Icons.apple, size: 20),
            onPressed: () {},
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
        _specimen(
          'Google branded',
          SignInButton(
            label: 'Continue with Google',
            icon: const Icon(Icons.g_mobiledata, size: 24),
            onPressed: () {},
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  /// Health score that produces the given tier.
  static double _scoreForTier(HealthTier tier) {
    switch (tier) {
      case HealthTier.healthy:
        return 0.95;
      case HealthTier.brownout:
        return 0.65;
      case HealthTier.cascade:
        return 0.45;
      case HealthTier.fracture:
        return 0.25;
      case HealthTier.collapse:
        return 0.08;
    }
  }
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------

Widget _section(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
      ),
    ),
  );
}

Widget _specimen(String label, Widget child) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder:
              (context) => Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}

Widget _specimenRow(String label, List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder:
              (context) => Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        ),
      ],
    ),
  );
}
