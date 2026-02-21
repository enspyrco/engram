import 'dart:convert';
import 'dart:io';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/quiz_session_state.dart';
import 'package:engram/src/models/session_mode.dart';
import 'package:engram/src/providers/graph_store_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/quiz_session_provider.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/storage/config.dart';
import 'package:engram/src/storage/local_graph_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late LocalGraphRepository store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('engram_quiz_test_');
    store = LocalGraphRepository(dataDir: tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  KnowledgeGraph graphWithDueItems(int count) {
    final concepts = <Concept>[];
    final items = <QuizItem>[];
    for (var i = 0; i < count; i++) {
      concepts.add(
        Concept(
          id: 'c$i',
          name: 'Concept $i',
          description: 'Desc $i',
          sourceDocumentId: 'doc1',
        ),
      );
      items.add(
        QuizItem(
          id: 'q$i',
          conceptId: 'c$i',
          question: 'Question $i?',
          answer: 'Answer $i.',
          easeFactor: 2.5,
          interval: 0,
          repetitions: 0,
          nextReview: DateTime.utc(2020),
          lastReview: null,
        ),
      );
    }
    return KnowledgeGraph(concepts: concepts, quizItems: items);
  }

  Future<ProviderContainer> createContainer(
    KnowledgeGraph graph, {
    Map<String, Object> prefsValues = const {},
  }) async {
    final json = const JsonEncoder.withIndent('  ').convert(graph.toJson());
    File('${tempDir.path}/knowledge_graph.json').writeAsStringSync(json);

    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          () => _FakeSettingsNotifier(tempDir.path),
        ),
        graphRepositoryProvider.overrideWithValue(store),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('QuizSessionNotifier', () {
    test('initial state is idle', () async {
      final container = await createContainer(KnowledgeGraph.empty);
      final state = container.read(quizSessionProvider);
      expect(state.phase, QuizPhase.idle);
      expect(state.items, isEmpty);
    });

    test('startSession loads due items', () async {
      final graph = graphWithDueItems(3);
      final container = await createContainer(graph);

      // Wait for graph to load
      await container.read(knowledgeGraphProvider.future);

      container.read(quizSessionProvider.notifier).startSession();
      final state = container.read(quizSessionProvider);

      expect(state.phase, QuizPhase.question);
      expect(state.items, hasLength(3));
      expect(state.currentIndex, 0);
    });

    test('startSession with no due items goes to summary', () async {
      final container = await createContainer(
        KnowledgeGraph(
          concepts: [
            Concept(
              id: 'c1',
              name: 'C',
              description: 'D',
              sourceDocumentId: 'doc1',
            ),
          ],
          quizItems: [
            QuizItem(
              id: 'q1',
              conceptId: 'c1',
              question: 'Q?',
              answer: 'A.',
              easeFactor: 2.5,
              interval: 6,
              repetitions: 2,
              nextReview: DateTime.utc(2099),
              lastReview: null,
            ),
          ],
        ),
      );

      await container.read(knowledgeGraphProvider.future);
      container.read(quizSessionProvider.notifier).startSession();
      final state = container.read(quizSessionProvider);

      expect(state.phase, QuizPhase.summary);
    });

    test('revealAnswer transitions from question to revealed', () async {
      final container = await createContainer(graphWithDueItems(1));
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();
      notifier.revealAnswer();

      expect(container.read(quizSessionProvider).phase, QuizPhase.revealed);
    });

    test('rateItem advances to next question', () async {
      final container = await createContainer(graphWithDueItems(2));
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();
      notifier.revealAnswer();
      await notifier.rateItem(5);

      final state = container.read(quizSessionProvider);
      expect(state.phase, QuizPhase.question);
      expect(state.currentIndex, 1);
      expect(state.ratings, [5]);
    });

    test('rateItem on last item goes to summary', () async {
      final container = await createContainer(graphWithDueItems(1));
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();
      notifier.revealAnswer();
      await notifier.rateItem(4);

      final state = container.read(quizSessionProvider);
      expect(state.phase, QuizPhase.summary);
      expect(state.reviewedCount, 1);
      expect(state.correctCount, 1);
    });

    test('rateItem persists SM-2 updates', () async {
      final container = await createContainer(graphWithDueItems(1));
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();
      notifier.revealAnswer();
      await notifier.rateItem(5);

      final graph = await container.read(knowledgeGraphProvider.future);
      expect(graph.quizItems.first.repetitions, 1);
    });

    test('reset returns to idle', () async {
      final container = await createContainer(graphWithDueItems(1));
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();
      notifier.reset();

      expect(container.read(quizSessionProvider).phase, QuizPhase.idle);
    });

    test('completing session persists streak', () async {
      final container = await createContainer(graphWithDueItems(1));
      await container.read(knowledgeGraphProvider.future);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();
      notifier.revealAnswer();
      await notifier.rateItem(4);

      final repo = container.read(settingsRepositoryProvider);
      expect(repo.getCurrentStreak(), 1);
      expect(repo.getLongestStreak(), 1);
      expect(repo.getLastSessionDate(), isNotNull);
    });

    test('comeback detected when last session > 3 days ago', () async {
      // Set last session to 5 days ago
      final fiveDaysAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 5),
      );
      final dateStr =
          '${fiveDaysAgo.year}-${fiveDaysAgo.month.toString().padLeft(2, '0')}-${fiveDaysAgo.day.toString().padLeft(2, '0')}';

      final container = await createContainer(
        graphWithDueItems(10),
        prefsValues: {
          'last_session_date': dateStr,
          'current_streak': 3,
          'longest_streak': 5,
        },
      );
      await container.read(knowledgeGraphProvider.future);

      container.read(quizSessionProvider.notifier).startSession();
      final state = container.read(quizSessionProvider);

      expect(state.isComeback, isTrue);
      // Comeback overrides to quick mode (5 items max)
      expect(state.items.length, lessThanOrEqualTo(5));
      expect(state.sessionMode, SessionMode.quick);
    });

    test('quick mode caps at 5 items', () async {
      final container = await createContainer(graphWithDueItems(10));
      await container.read(knowledgeGraphProvider.future);

      container
          .read(quizSessionProvider.notifier)
          .startSession(mode: SessionMode.quick);
      final state = container.read(quizSessionProvider);

      expect(state.items.length, 5);
      expect(state.sessionMode, SessionMode.quick);
    });

    test('allDue mode returns all due items', () async {
      final container = await createContainer(graphWithDueItems(25));
      await container.read(knowledgeGraphProvider.future);

      container
          .read(quizSessionProvider.notifier)
          .startSession(mode: SessionMode.allDue);
      final state = container.read(quizSessionProvider);

      expect(state.items.length, 25);
      expect(state.sessionMode, SessionMode.allDue);
    });
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._dataDir);
  final String _dataDir;

  @override
  EngramConfig build() => EngramConfig(dataDir: _dataDir);
}
