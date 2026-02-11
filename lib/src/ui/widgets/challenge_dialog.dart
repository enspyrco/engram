import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/challenge.dart';
import '../../models/concept.dart';
import '../../models/friend.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/user_profile_provider.dart';

const _uuid = Uuid();

/// Minimum SM-2 repetitions to consider a concept "mastered".
const int kMasteryMinRepetitions = 3;

/// Minimum SM-2 ease factor to consider a concept "mastered".
/// 2.5 is the initial ease factor — meaning the concept hasn't gotten harder.
const double kMasteryMinEaseFactor = 2.5;

/// Dialog to pick a mastered concept and send a challenge to a friend.
class ChallengeDialog extends ConsumerStatefulWidget {
  const ChallengeDialog({super.key, required this.friend});

  final Friend friend;

  @override
  ConsumerState<ChallengeDialog> createState() => _ChallengeDialogState();
}

class _ChallengeDialogState extends ConsumerState<ChallengeDialog> {
  Concept? _selectedConcept;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final graphAsync = ref.watch(knowledgeGraphProvider);

    return AlertDialog(
      title: Text('Challenge ${widget.friend.displayName}'),
      content: graphAsync.when(
        data: (graph) {
          // Find concepts the current user has mastered
          // (quiz items with easeFactor >= 2.5 and repetitions >= 3)
          final masteredConceptIds = graph.quizItems
              .where((q) =>
                  q.repetitions >= kMasteryMinRepetitions &&
                  q.easeFactor >= kMasteryMinEaseFactor)
              .map((q) => q.conceptId)
              .toSet();

          final masteredConcepts = graph.concepts
              .where((c) => masteredConceptIds.contains(c.id))
              .toList();

          if (masteredConcepts.isEmpty) {
            return const Text(
              'You need to master some concepts first before you can challenge a friend.',
            );
          }

          return SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pick a concept you\'ve mastered:'),
                const SizedBox(height: 8),
                Flexible(
                  child: RadioGroup<Concept>(
                    groupValue: _selectedConcept,
                    onChanged: (c) =>
                        setState(() => _selectedConcept = c),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: masteredConcepts.length,
                      itemBuilder: (context, index) {
                        final concept = masteredConcepts[index];
                        return ListTile(
                          title: Text(concept.name),
                          leading: Radio<Concept>(value: concept),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedConcept == null || _sending
              ? null
              : _sendChallenge,
          child: _sending
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator())
              : const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _sendChallenge() async {
    if (_selectedConcept == null) return;

    setState(() => _sending = true);

    try {
      final graph = ref.read(knowledgeGraphProvider).valueOrNull;
      if (graph == null) return;

      // Find a quiz item for this concept
      final quizItem = graph.quizItems.firstWhere(
        (q) => q.conceptId == _selectedConcept!.id,
      );

      final user = ref.read(authStateProvider).valueOrNull;
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (user == null) return;

      final challenge = Challenge(
        id: 'challenge_${_uuid.v4()}',
        fromUid: user.uid,
        fromName: profile?.displayName ?? 'Someone',
        toUid: widget.friend.uid,
        quizItemSnapshot: quizItem.toJson(),
        conceptName: _selectedConcept!.name,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      await ref.read(challengeProvider.notifier).sendChallenge(challenge);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send challenge: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
