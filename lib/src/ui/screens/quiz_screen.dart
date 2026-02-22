import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quiz_item.dart';
import '../../models/quiz_session_state.dart';
import '../../models/session_mode.dart';
import '../../engine/review_rating.dart';
import '../../providers/collection_filter_provider.dart';
import '../../providers/knowledge_graph_provider.dart';
import '../../providers/quiz_session_provider.dart';
import '../../providers/split_concept_provider.dart';
import '../../providers/topic_provider.dart';
import '../widgets/fsrs_rating_bar.dart';
import '../widgets/quality_rating_bar.dart';
import '../widgets/quiz_card.dart';
import '../widgets/session_summary.dart';
import '../widgets/split_concept_sheet.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(quizSessionProvider);
    final hasItems = ref.watch(
      knowledgeGraphProvider.select(
        (av) => av.valueOrNull?.quizItems.isNotEmpty ?? false,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: switch (session.phase) {
        QuizPhase.idle => _IdleView(
          hasItems: hasItems,
          isComeback: session.isComeback,
          daysSinceLastSession: session.daysSinceLastSession,
          onStart:
              ({
                required SessionMode mode,
                String? collectionId,
                String? topicId,
              }) => ref
                  .read(quizSessionProvider.notifier)
                  .startSession(
                    mode: mode,
                    collectionId: collectionId,
                    topicId: topicId,
                  ),
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

class _IdleView extends ConsumerWidget {
  const _IdleView({
    required this.hasItems,
    required this.isComeback,
    required this.daysSinceLastSession,
    required this.onStart,
  });

  final bool hasItems;
  final bool isComeback;
  final int? daysSinceLastSession;
  final void Function({
    required SessionMode mode,
    String? collectionId,
    String? topicId,
  })
  onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (!hasItems) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No quiz items yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Ingest a collection to create quiz items.'),
          ],
        ),
      );
    }

    final topics = ref.watch(availableTopicsProvider);
    final selectedTopicId = ref.watch(selectedTopicIdProvider);
    final collections = ref.watch(availableCollectionsProvider);
    final selectedCollectionId = ref.watch(selectedCollectionIdProvider);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Topic filter (preferred)
          if (topics.isNotEmpty) ...[
            DropdownButton<String?>(
              value: selectedTopicId,
              onChanged: (value) {
                ref.read(selectedTopicIdProvider.notifier).state = value;
                // Clear collection when topic is selected
                if (value != null) {
                  ref.read(selectedCollectionIdProvider.notifier).state = null;
                }
              },
              items: [
                const DropdownMenuItem(value: null, child: Text('All topics')),
                for (final t in topics)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Collection filter (fallback)
          if (collections.isNotEmpty && selectedTopicId == null) ...[
            DropdownButton<String?>(
              value: selectedCollectionId,
              onChanged:
                  (value) =>
                      ref.read(selectedCollectionIdProvider.notifier).state =
                          value,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All collections'),
                ),
                for (final c in collections)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (isComeback && daysSinceLastSession != null) ...[
            Icon(Icons.waving_hand, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Welcome back!', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              "It's been $daysSinceLastSession days. Quick refresher (5 items).",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  () => onStart(
                    mode: SessionMode.quick,
                    collectionId: selectedCollectionId,
                    topicId: selectedTopicId,
                  ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Refresher'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed:
                  () => onStart(
                    mode: SessionMode.full,
                    collectionId: selectedCollectionId,
                    topicId: selectedTopicId,
                  ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Full Session'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  () => onStart(
                    mode: SessionMode.quick,
                    collectionId: selectedCollectionId,
                    topicId: selectedTopicId,
                  ),
              icon: const Icon(Icons.bolt),
              label: const Text('Quick (5 min)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  () => onStart(
                    mode: SessionMode.allDue,
                    collectionId: selectedCollectionId,
                    topicId: selectedTopicId,
                  ),
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
              onPressed:
                  () => ref.read(quizSessionProvider.notifier).revealAnswer(),
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
          if (item.isFsrs)
            FsrsRatingBar(
              onRate:
                  (rating) => ref
                      .read(quizSessionProvider.notifier)
                      .rateItem(FsrsReviewRating(rating)),
            )
          else
            QualityRatingBar(
              onRate:
                  (quality) => ref
                      .read(quizSessionProvider.notifier)
                      .rateItem(Sm2Rating(quality)),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showSplitSheet(context, ref, item),
            icon: const Icon(Icons.call_split, size: 18),
            label: const Text('Split this concept'),
          ),
        ],
      ),
    );
  }

  void _showSplitSheet(BuildContext context, WidgetRef ref, QuizItem item) {
    // Look up the concept for this quiz item
    final graph = ref.read(knowledgeGraphProvider).valueOrNull;
    if (graph == null) return;

    final concept =
        graph.concepts.where((c) => c.id == item.conceptId).firstOrNull;
    if (concept == null) return;

    ref
        .read(splitConceptProvider.notifier)
        .requestSplit(
          conceptId: concept.id,
          conceptName: concept.name,
          conceptDescription: concept.description,
          sourceDocumentId: concept.sourceDocumentId,
          quizQuestion: item.question,
          quizAnswer: item.answer,
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SplitConceptSheet(),
    );
  }
}
