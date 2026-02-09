import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/ui/screens/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  KnowledgeGraph graphWithDueItems(int count) {
    final concepts = <Concept>[];
    final items = <QuizItem>[];
    for (var i = 0; i < count; i++) {
      concepts.add(Concept(
        id: 'c$i',
        name: 'Concept $i',
        description: 'Desc $i',
        sourceDocumentId: 'doc1',
      ));
      items.add(QuizItem(
        id: 'q$i',
        conceptId: 'c$i',
        question: 'Question $i?',
        answer: 'Answer $i.',
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        nextReview: '2020-01-01T00:00:00.000Z',
        lastReview: null,
      ));
    }
    return KnowledgeGraph(concepts: concepts, quizItems: items);
  }

  Future<Widget> buildApp(KnowledgeGraph graph) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        knowledgeGraphProvider
            .overrideWith(() => _PreloadedGraphNotifier(graph)),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: QuizScreen()),
    );
  }

  group('QuizScreen', () {
    testWidgets('shows empty state when no quiz items', (tester) async {
      await tester.pumpWidget(await buildApp(KnowledgeGraph.empty));
      await tester.pumpAndSettle();

      expect(find.text('No quiz items yet'), findsOneWidget);
    });

    testWidgets('shows start button when items exist', (tester) async {
      await tester.pumpWidget(await buildApp(graphWithDueItems(2)));
      await tester.pumpAndSettle();

      expect(find.text('Full Session'), findsOneWidget);
    });

    testWidgets('start shows question card', (tester) async {
      await tester.pumpWidget(await buildApp(graphWithDueItems(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full Session'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 1'), findsOneWidget);
      expect(find.text('Question 0?'), findsOneWidget);
      expect(find.text('Reveal Answer'), findsOneWidget);
    });

    testWidgets('reveal shows answer and rating buttons', (tester) async {
      await tester.pumpWidget(await buildApp(graphWithDueItems(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full Session'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reveal Answer'));
      await tester.pumpAndSettle();

      expect(find.text('Answer 0.'), findsOneWidget);
      expect(find.text('Rate your recall:'), findsOneWidget);
      // 6 rating buttons (0-5)
      for (var i = 0; i <= 5; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('rating completes session with one item', (tester) async {
      await tester.pumpWidget(await buildApp(graphWithDueItems(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full Session'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reveal Answer'));
      await tester.pumpAndSettle();

      // Tap the "5" (Perfect) rating button
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      expect(find.text('Session Complete'), findsOneWidget);
      expect(find.text('1 reviewed'), findsOneWidget);
    });

    testWidgets('done button returns to idle', (tester) async {
      await tester.pumpWidget(await buildApp(graphWithDueItems(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reveal Answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Full Session'), findsOneWidget);
    });
  });
}

class _PreloadedGraphNotifier extends KnowledgeGraphNotifier {
  _PreloadedGraphNotifier(this._graph);
  final KnowledgeGraph _graph;

  @override
  Future<KnowledgeGraph> build() async => _graph;

  @override
  Future<void> updateQuizItem(QuizItem updated) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.withUpdatedQuizItem(updated));
  }
}
