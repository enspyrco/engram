import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quiz_session_state.dart';
import '../../models/session_mode.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/quiz_session_provider.dart';
import '../widgets/quality_rating_bar.dart';
import '../widgets/quiz_card.dart';
import '../widgets/session_summary.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(quizSessionProvider);
    final graphAsync = ref.watch(knowledgeGraphProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: switch (session.phase) {
        QuizPhase.idle => _IdleView(
            hasItems: graphAsync.valueOrNull?.quizItems.isNotEmpty ?? false,
            isComeback: session.isComeback,
            daysSinceLastSession: session.daysSinceLastSession,
            onStart: (mode) =>
                ref.read(quizSessionProvider.notifier).startSession(mode: mode),
          ),
        QuizPhase.question => _QuestionView(session: session),
        QuizPhase.revealed => _RevealedView(session: session),
        QuizPhase.summary => SessionSummary(
            state: session,
            onDone: () => ref.read(quizSessionProvider.notifier).reset(),
          ),
      },
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.hasItems,
    required this.isComeback,
    required this.daysSinceLastSession,
    required this.onStart,
  });

  final bool hasItems;
  final bool isComeback;
  final int? daysSinceLastSession;
  final void Function(SessionMode mode) onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!hasItems) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 64,
                color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No quiz items yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Ingest a collection to create quiz items.'),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isComeback && daysSinceLastSession != null) ...[
            Icon(Icons.waving_hand, size: 48,
                color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Welcome back!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              "It's been $daysSinceLastSession days. Quick refresher (5 items).",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => onStart(SessionMode.quick),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Refresher'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => onStart(SessionMode.full),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Full Session'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onStart(SessionMode.quick),
              icon: const Icon(Icons.bolt),
              label: const Text('Quick (5 min)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onStart(SessionMode.allDue),
              icon: const Icon(Icons.all_inclusive),
              label: const Text('All Due'),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionView extends ConsumerWidget {
  const _QuestionView({required this.session});

  final QuizSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = session.currentItem;
    if (item == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: QuizCard(
                question: item.question,
                index: session.currentIndex,
                total: session.totalItems,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () =>
                  ref.read(quizSessionProvider.notifier).revealAnswer(),
              child: const Text('Reveal Answer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealedView extends ConsumerWidget {
  const _RevealedView({required this.session});

  final QuizSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = session.currentItem;
    if (item == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: QuizCard(
                question: item.question,
                answer: item.answer,
                index: session.currentIndex,
                total: session.totalItems,
              ),
            ),
          ),
          const SizedBox(height: 16),
          QualityRatingBar(
            onRate: (quality) =>
                ref.read(quizSessionProvider.notifier).rateItem(quality),
          ),
        ],
      ),
    );
  }
}
