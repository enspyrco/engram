import 'package:engram/src/engine/scheduler.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:test/test.dart';

QuizItem _makeItem(
  String id, {
  required String nextReview,
  String conceptId = 'c1',
  int repetitions = 1,
}) {
  return QuizItem(
    id: id,
    conceptId: conceptId,
    question: 'Q?',
    answer: 'A.',
    easeFactor: 2.5,
    interval: 1,
    repetitions: repetitions,
    nextReview: nextReview,
    lastReview: null,
  );
}

Concept _concept(String id) => Concept(
      id: id,
      name: id,
      description: 'desc',
      sourceDocumentId: 'doc1',
      tags: const [],
    );

Relationship _dep(String from, String to) => Relationship(
      id: '$from-$to',
      fromConceptId: from,
      toConceptId: to,
      label: 'depends on',
    );

/// Wrap quiz items in a KnowledgeGraph with no relationships,
/// so all concepts are unlocked (preserving Phase 1 behavior).
KnowledgeGraph _graphOf(List<QuizItem> items) {
  final conceptIds = items.map((i) => i.conceptId).toSet();
  return KnowledgeGraph(
    concepts: [for (final id in conceptIds) _concept(id)],
    quizItems: items,
  );
}

void main() {
  final now = DateTime.utc(2025, 6, 15, 12, 0);

  group('scheduleDueItems (basic)', () {
    test('returns items due before now', () {
      final items = [
        _makeItem('q1', nextReview: '2025-06-14T00:00:00.000Z'), // due
        _makeItem('q2', nextReview: '2025-06-15T12:00:00.000Z'), // due (exact)
        _makeItem('q3', nextReview: '2025-06-16T00:00:00.000Z'), // not due
      ];

      final due = scheduleDueItems(_graphOf(items), now: now);

      expect(due.length, 2);
      expect(due.map((i) => i.id), containsAll(['q1', 'q2']));
    });

    test('sorts oldest due first', () {
      final items = [
        _makeItem('q2', nextReview: '2025-06-14T00:00:00.000Z'),
        _makeItem('q1', nextReview: '2025-06-10T00:00:00.000Z'),
        _makeItem('q3', nextReview: '2025-06-15T00:00:00.000Z'),
      ];

      final due = scheduleDueItems(_graphOf(items), now: now);

      expect(due.first.id, 'q1');
      expect(due[1].id, 'q2');
      expect(due.last.id, 'q3');
    });

    test('caps at maxSessionSize', () {
      final items = List.generate(
        30,
        (i) => _makeItem('q$i', nextReview: '2025-06-01T00:00:00.000Z'),
      );

      final due = scheduleDueItems(_graphOf(items), now: now);

      expect(due.length, maxSessionSize);
    });

    test('returns empty list when nothing is due', () {
      final items = [
        _makeItem('q1', nextReview: '2025-06-16T00:00:00.000Z'),
        _makeItem('q2', nextReview: '2025-06-20T00:00:00.000Z'),
      ];

      final due = scheduleDueItems(_graphOf(items), now: now);

      expect(due, isEmpty);
    });

    test('returns empty list for empty input', () {
      final due = scheduleDueItems(KnowledgeGraph.empty, now: now);
      expect(due, isEmpty);
    });
  });

  group('scheduleDueItems (graph-aware)', () {
    test('filters out items from locked concepts', () {
      // b depends on a; a not mastered → b is locked
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_dep('b', 'a')],
        quizItems: [
          _makeItem('q1', conceptId: 'a', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 0),
          _makeItem('q2', conceptId: 'b', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 0),
        ],
      );

      final due = scheduleDueItems(graph, now: now);

      expect(due.map((i) => i.id), ['q1']);
    });

    test('unlocks dependent when prerequisite mastered', () {
      // b depends on a; a mastered → b is unlocked
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_dep('b', 'a')],
        quizItems: [
          _makeItem('q1', conceptId: 'a', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 1),
          _makeItem('q2', conceptId: 'b', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 0),
        ],
      );

      final due = scheduleDueItems(graph, now: now);

      expect(due.map((i) => i.id), containsAll(['q1', 'q2']));
    });

    test('foundational concepts sort before non-foundational', () {
      // b depends on a; both unlocked and due
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [_dep('b', 'a')],
        quizItems: [
          // b is due earlier, but a is foundational
          _makeItem('q-b', conceptId: 'b', nextReview: '2025-06-10T00:00:00.000Z', repetitions: 0),
          _makeItem('q-a', conceptId: 'a', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 1),
        ],
      );

      final due = scheduleDueItems(graph, now: now);

      // a is foundational, so it comes first even though b has earlier due date
      expect(due.first.id, 'q-a');
    });

    test('custom maxItems caps correctly', () {
      final items = List.generate(
        15,
        (i) => _makeItem('q$i',
            conceptId: 'c$i', nextReview: '2025-06-01T00:00:00.000Z'),
      );
      final graph = _graphOf(items);

      final due = scheduleDueItems(graph, now: now, maxItems: 5);
      expect(due.length, 5);
    });

    test('maxItems null returns all due', () {
      final items = List.generate(
        30,
        (i) => _makeItem('q$i',
            conceptId: 'c$i', nextReview: '2025-06-01T00:00:00.000Z'),
      );
      final graph = _graphOf(items);

      final due = scheduleDueItems(graph, now: now, maxItems: null);
      expect(due.length, 30);
    });

    test('non-dependency relationships do not block', () {
      final graph = KnowledgeGraph(
        concepts: [_concept('a'), _concept('b')],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'b',
            toConceptId: 'a',
            label: 'is a type of',
          ),
        ],
        quizItems: [
          _makeItem('q1', conceptId: 'a', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 0),
          _makeItem('q2', conceptId: 'b', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 0),
        ],
      );

      final due = scheduleDueItems(graph, now: now);

      // Both should appear — "is a type of" is not a dependency
      expect(due.length, 2);
    });
  });

  group('scheduleDueItems (collection filter)', () {
    test('filters to items from selected collection', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'a',
            description: 'desc',
            sourceDocumentId: 'doc1',
          ),
          Concept(
            id: 'b',
            name: 'b',
            description: 'desc',
            sourceDocumentId: 'doc2',
          ),
        ],
        quizItems: [
          _makeItem('q1', conceptId: 'a', nextReview: '2025-06-14T00:00:00.000Z'),
          _makeItem('q2', conceptId: 'b', nextReview: '2025-06-14T00:00:00.000Z'),
        ],
        documentMetadata: const [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Doc 1',
            updatedAt: '2025-01-01',
            ingestedAt: '2025-01-01',
            collectionId: 'col-x',
            collectionName: 'X',
          ),
          DocumentMetadata(
            documentId: 'doc2',
            title: 'Doc 2',
            updatedAt: '2025-01-01',
            ingestedAt: '2025-01-01',
            collectionId: 'col-y',
            collectionName: 'Y',
          ),
        ],
      );

      final due = scheduleDueItems(graph, now: now, collectionId: 'col-x');

      expect(due.length, 1);
      expect(due.first.id, 'q1');
    });

    test('null collectionId returns all due items', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'a',
            description: 'desc',
            sourceDocumentId: 'doc1',
          ),
          Concept(
            id: 'b',
            name: 'b',
            description: 'desc',
            sourceDocumentId: 'doc2',
          ),
        ],
        quizItems: [
          _makeItem('q1', conceptId: 'a', nextReview: '2025-06-14T00:00:00.000Z'),
          _makeItem('q2', conceptId: 'b', nextReview: '2025-06-14T00:00:00.000Z'),
        ],
        documentMetadata: const [
          DocumentMetadata(
            documentId: 'doc1',
            title: 'Doc 1',
            updatedAt: '2025-01-01',
            ingestedAt: '2025-01-01',
            collectionId: 'col-x',
            collectionName: 'X',
          ),
          DocumentMetadata(
            documentId: 'doc2',
            title: 'Doc 2',
            updatedAt: '2025-01-01',
            ingestedAt: '2025-01-01',
            collectionId: 'col-y',
            collectionName: 'Y',
          ),
        ],
      );

      final due = scheduleDueItems(graph, now: now);

      expect(due.length, 2);
    });

    test('collection filter respects graph-wide unlocking', () {
      // Concept b (col-x) depends on concept a (col-y).
      // a is not mastered → b is locked.
      // Filtering to col-x should return nothing even though b is due.
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'a',
            description: 'desc',
            sourceDocumentId: 'doc-y',
          ),
          Concept(
            id: 'b',
            name: 'b',
            description: 'desc',
            sourceDocumentId: 'doc-x',
          ),
        ],
        relationships: [_dep('b', 'a')],
        quizItems: [
          _makeItem('q1', conceptId: 'a', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 0),
          _makeItem('q2', conceptId: 'b', nextReview: '2025-06-14T00:00:00.000Z', repetitions: 0),
        ],
        documentMetadata: const [
          DocumentMetadata(
            documentId: 'doc-y',
            title: 'Doc Y',
            updatedAt: '2025-01-01',
            ingestedAt: '2025-01-01',
            collectionId: 'col-y',
            collectionName: 'Y',
          ),
          DocumentMetadata(
            documentId: 'doc-x',
            title: 'Doc X',
            updatedAt: '2025-01-01',
            ingestedAt: '2025-01-01',
            collectionId: 'col-x',
            collectionName: 'X',
          ),
        ],
      );

      final due = scheduleDueItems(graph, now: now, collectionId: 'col-x');

      // b is locked (a not mastered), so nothing from col-x is due
      expect(due, isEmpty);
    });
  });
}
