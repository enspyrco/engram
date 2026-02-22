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
      concepts.add(
        Concept(
          id: 'c$i',
          name: 'Concept $i',
          description: 'Desc $i',
          sourceDocumentId: 'doc1',
        ),
      );
      items.add(
        QuizItem.newCard(
          id: 'q$i',
          conceptId: 'c$i',
          question: 'Question $i?',
          answer: 'Answer $i.',
          now: DateTime.utc(2020),
        ),
      );
    }
    return KnowledgeGraph(concepts: concepts, quizItems: items);
  }

  Future<Widget> buildApp(KnowledgeGraph graph) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        knowledgeGraphProvider.overrideWith(
          () => _PreloadedGraphNotifier(graph),
        ),
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

    testWidgets('reveal shows answer and FSRS rating buttons', (tester) async {
      await tester.pumpWidget(await buildApp(graphWithDueItems(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full Session'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reveal Answer'));
      await tester.pumpAndSettle();

      expect(find.text('Answer 0.'), findsOneWidget);
      expect(find.text('Rate your recall:'), findsOneWidget);
      // 4-button FSRS rating bar
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
    });

    testWidgets('rating completes session with one item', (tester) async {
      await tester.pumpWidget(await buildApp(graphWithDueItems(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full Session'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reveal Answer'));
      await tester.pumpAndSettle();

      // Tap the "Easy" FSRS rating button
      await tester.tap(find.text('Easy'));
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
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Full Session'), findsOneWidget);
    });

    testWidgets('always shows 4-button FSRS rating bar', (tester) async {
      await tester.pumpWidget(await buildApp(graphWithDueItems(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reveal Answer'));
      await tester.pumpAndSettle();

      // FSRS shows 4 buttons
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      // SM-2 buttons should NOT be present
      expect(find.text('Blackout'), findsNothing);
      expect(find.text('Perfect'), findsNothing);
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
