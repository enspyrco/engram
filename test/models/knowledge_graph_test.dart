import 'dart:convert';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/models/topic.dart';
import 'package:test/test.dart';

void main() {
  group('Concept', () {
    test('fromJson/toJson round-trips', () {
      final concept = Concept(
        id: 'test-concept',
        name: 'Test Concept',
        description: 'A test concept',
        sourceDocumentId: 'doc-1',
        tags: ['test', 'example'],
      );

      final json = concept.toJson();
      final restored = Concept.fromJson(json);

      expect(restored.id, concept.id);
      expect(restored.name, concept.name);
      expect(restored.description, concept.description);
      expect(restored.sourceDocumentId, concept.sourceDocumentId);
      expect(restored.tags, concept.tags);
    });

    test('fromJson handles missing tags', () {
      final concept = Concept.fromJson({
        'id': 'test',
        'name': 'Test',
        'description': 'Desc',
        'sourceDocumentId': 'doc-1',
      });

      expect(concept.tags, isEmpty);
    });

    test('withSourceDocumentId creates new instance', () {
      final concept = Concept(
        id: 'c1',
        name: 'C1',
        description: 'Desc',
        sourceDocumentId: '',
      );

      final updated = concept.withSourceDocumentId('doc-1');
      expect(updated.sourceDocumentId, 'doc-1');
      expect(updated.id, 'c1');
      expect(concept.sourceDocumentId, ''); // Original unchanged
    });
  });

  group('Relationship', () {
    test('fromJson/toJson round-trips', () {
      const rel = Relationship(
        id: 'r1',
        fromConceptId: 'c1',
        toConceptId: 'c2',
        label: 'depends on',
        description: 'C1 depends on C2',
      );

      final json = rel.toJson();
      final restored = Relationship.fromJson(json);

      expect(restored.id, rel.id);
      expect(restored.fromConceptId, rel.fromConceptId);
      expect(restored.toConceptId, rel.toConceptId);
      expect(restored.label, rel.label);
      expect(restored.description, rel.description);
    });

    test('toJson omits null description', () {
      const rel = Relationship(
        id: 'r1',
        fromConceptId: 'c1',
        toConceptId: 'c2',
        label: 'enables',
      );

      final json = rel.toJson();
      expect(json.containsKey('description'), isFalse);
    });
  });

  group('QuizItem', () {
    test('newCard sets SM-2 defaults', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
      );

      expect(item.easeFactor, 2.5);
      expect(item.interval, 0);
      expect(item.repetitions, 0);
      expect(item.lastReview, isNull);
    });

    test('fromJson/toJson round-trips', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
      );

      final json = item.toJson();
      final restored = QuizItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.conceptId, item.conceptId);
      expect(restored.question, item.question);
      expect(restored.answer, item.answer);
      expect(restored.easeFactor, item.easeFactor);
      expect(restored.interval, item.interval);
      expect(restored.repetitions, item.repetitions);
      expect(restored.nextReview, item.nextReview);
    });

    test('newCard without predictedDifficulty has null FSRS fields', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
      );

      expect(item.difficulty, isNull);
      expect(item.stability, isNull);
      expect(item.fsrsState, isNull);
      expect(item.lapses, isNull);
    });

    test('newCard with predictedDifficulty sets difficulty', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
        predictedDifficulty: 6.0,
      );

      expect(item.difficulty, 6.0);
      expect(item.stability, isNull);
      expect(item.fsrsState, isNull);
      expect(item.lapses, isNull);
    });

    test('fromJson/toJson round-trips with FSRS fields', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
        easeFactor: 2.5,
        interval: 6,
        repetitions: 2,
        nextReview: DateTime.utc(2025, 1, 10),
        lastReview: DateTime.utc(2025, 1, 4),
        difficulty: 5.5,
        stability: 12.3,
        fsrsState: 2,
        lapses: 1,
      );

      final json = item.toJson();
      final restored = QuizItem.fromJson(json);

      expect(restored.difficulty, 5.5);
      expect(restored.stability, 12.3);
      expect(restored.fsrsState, 2);
      expect(restored.lapses, 1);
    });

    test('fromJson handles missing FSRS fields (backward compat)', () {
      final json = {
        'id': 'q1',
        'conceptId': 'c1',
        'question': 'What is X?',
        'answer': 'X is Y.',
        'easeFactor': 2.5,
        'interval': 0,
        'repetitions': 0,
        'nextReview': '2025-01-01T00:00:00.000Z',
        'lastReview': null,
      };

      final item = QuizItem.fromJson(json);

      expect(item.difficulty, isNull);
      expect(item.stability, isNull);
      expect(item.fsrsState, isNull);
      expect(item.lapses, isNull);
    });

    test('toJson omits null FSRS fields', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
      );

      final json = item.toJson();

      expect(json.containsKey('difficulty'), isFalse);
      expect(json.containsKey('stability'), isFalse);
      expect(json.containsKey('fsrsState'), isFalse);
      expect(json.containsKey('lapses'), isFalse);
    });

    test('toJson includes non-null FSRS fields', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
        predictedDifficulty: 6.0,
      );

      final json = item.toJson();

      expect(json['difficulty'], 6.0);
      expect(json.containsKey('stability'), isFalse);
    });

    test('withFsrsReview updates FSRS fields and preserves SM-2 fields', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
        predictedDifficulty: 5.0,
      );

      final updated = item.withFsrsReview(
        difficulty: 4.8,
        stability: 10.5,
        fsrsState: 2,
        lapses: 0,
        interval: 10,
        nextReview: DateTime.utc(2025, 1, 11),
      );

      // FSRS fields updated
      expect(updated.difficulty, 4.8);
      expect(updated.stability, 10.5);
      expect(updated.fsrsState, 2);
      expect(updated.lapses, 0);
      expect(updated.interval, 10);
      expect(updated.nextReview, DateTime.utc(2025, 1, 11));
      expect(updated.lastReview, isNotNull);

      // SM-2 fields preserved
      expect(updated.easeFactor, 2.5);
      expect(updated.repetitions, 0);

      // Original unchanged
      expect(item.difficulty, 5.0);
      expect(item.interval, 0);
    });

    test('withReview preserves FSRS fields', () {
      final item = QuizItem(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        nextReview: DateTime.utc(2025),
        lastReview: null,
        difficulty: 6.0,
        stability: 3.26,
        fsrsState: 1,
        lapses: 0,
      );

      final updated = item.withReview(
        easeFactor: 2.6,
        interval: 1,
        repetitions: 1,
        nextReview: DateTime.utc(2025, 1, 2),
      );

      // FSRS fields preserved
      expect(updated.difficulty, 6.0);
      expect(updated.stability, 3.26);
      expect(updated.fsrsState, 1);
      expect(updated.lapses, 0);
    });

    test('withReview updates SM-2 state', () {
      final item = QuizItem.newCard(
        id: 'q1',
        conceptId: 'c1',
        question: 'What is X?',
        answer: 'X is Y.',
      );

      final updated = item.withReview(
        easeFactor: 2.6,
        interval: 1,
        repetitions: 1,
        nextReview: DateTime.utc(2025, 1, 2),
      );

      expect(updated.easeFactor, 2.6);
      expect(updated.interval, 1);
      expect(updated.repetitions, 1);
      expect(updated.nextReview, DateTime.utc(2025, 1, 2));
      expect(updated.lastReview, isNotNull);
      // Original unchanged
      expect(item.easeFactor, 2.5);
    });
  });

  group('DocumentMetadata', () {
    test('fromJson/toJson round-trips', () {
      final meta = DocumentMetadata(
        documentId: 'doc-1',
        title: 'Test Doc',
        updatedAt: '2025-01-01T00:00:00.000Z',
        ingestedAt: DateTime.utc(2025, 1, 1, 1),
      );

      final json = meta.toJson();
      final restored = DocumentMetadata.fromJson(json);

      expect(restored.documentId, meta.documentId);
      expect(restored.title, meta.title);
      expect(restored.updatedAt, meta.updatedAt);
      expect(restored.ingestedAt, meta.ingestedAt);
    });
  });

  group('KnowledgeGraph', () {
    test('empty graph serializes to empty lists', () {
      final graph = KnowledgeGraph();
      final json = graph.toJson();

      expect(json['concepts'], isEmpty);
      expect(json['relationships'], isEmpty);
      expect(json['quizItems'], isEmpty);
      expect(json['documentMetadata'], isEmpty);
    });

    test('full round-trip through JSON string', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Concept 1',
            description: 'Desc 1',
            sourceDocumentId: 'doc-1',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'c1',
            toConceptId: 'c1',
            label: 'self-referential',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc-1',
            title: 'Doc 1',
            updatedAt: '2025-01-01T00:00:00.000Z',
            ingestedAt: DateTime.utc(2025, 1, 1, 1),
          ),
        ],
      );

      final jsonStr = jsonEncode(graph.toJson());
      final restored = KnowledgeGraph.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );

      expect(restored.concepts.length, 1);
      expect(restored.relationships.length, 1);
      expect(restored.quizItems.length, 1);
      expect(restored.documentMetadata.length, 1);
      expect(restored.concepts.first.id, 'c1');
    });

    test('withNewExtraction adds new data', () {
      final graph = KnowledgeGraph();

      final result = ExtractionResult(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C1',
            description: 'Desc',
            sourceDocumentId: '',
          ),
        ],
        relationships: const [],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
      );

      final updated = graph.withNewExtraction(
        result,
        documentId: 'doc-1',
        documentTitle: 'Doc 1',
        updatedAt: '2025-01-01',
      );

      expect(updated.concepts.length, 1);
      expect(updated.concepts.first.sourceDocumentId, 'doc-1');
      expect(updated.quizItems.length, 1);
      expect(updated.documentMetadata.length, 1);
    });

    test('withNewExtraction replaces data from same document', () {
      final initial = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Old',
            description: 'Old desc',
            sourceDocumentId: 'doc-1',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Old Q?',
            answer: 'Old A.',
          ),
        ],
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc-1',
            title: 'Doc 1',
            updatedAt: '2025-01-01',
            ingestedAt: DateTime.utc(2025),
          ),
        ],
      );

      final result = ExtractionResult(
        concepts: [
          Concept(
            id: 'c2',
            name: 'New',
            description: 'New desc',
            sourceDocumentId: '',
          ),
        ],
        relationships: const [],
        quizItems: [
          QuizItem.newCard(
            id: 'q2',
            conceptId: 'c2',
            question: 'New Q?',
            answer: 'New A.',
          ),
        ],
      );

      final updated = initial.withNewExtraction(
        result,
        documentId: 'doc-1',
        documentTitle: 'Doc 1',
        updatedAt: '2025-01-02',
      );

      expect(updated.concepts.length, 1);
      expect(updated.concepts.first.id, 'c2');
      expect(updated.quizItems.length, 1);
      expect(updated.quizItems.first.id, 'q2');
      expect(updated.documentMetadata.length, 1);
    });

    test('withNewExtraction preserves data from other documents', () {
      final initial = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'From Doc 1',
            description: 'Desc',
            sourceDocumentId: 'doc-1',
          ),
        ],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q1?',
            answer: 'A1.',
          ),
        ],
      );

      final result = ExtractionResult(
        concepts: [
          Concept(
            id: 'c2',
            name: 'From Doc 2',
            description: 'Desc',
            sourceDocumentId: '',
          ),
        ],
        relationships: const [],
        quizItems: [
          QuizItem.newCard(
            id: 'q2',
            conceptId: 'c2',
            question: 'Q2?',
            answer: 'A2.',
          ),
        ],
      );

      final updated = initial.withNewExtraction(
        result,
        documentId: 'doc-2',
        documentTitle: 'Doc 2',
        updatedAt: '2025-01-01',
      );

      expect(updated.concepts.length, 2);
      expect(updated.quizItems.length, 2);
    });

    test('withNewExtraction stores collection info on metadata', () {
      final graph = KnowledgeGraph();

      final result = ExtractionResult(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C1',
            description: 'Desc',
            sourceDocumentId: '',
          ),
        ],
        relationships: const [],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
      );

      final updated = graph.withNewExtraction(
        result,
        documentId: 'doc-1',
        documentTitle: 'Doc 1',
        updatedAt: '2025-01-01',
        collectionId: 'col-1',
        collectionName: 'Engineering',
      );

      expect(updated.documentMetadata.first.collectionId, 'col-1');
      expect(updated.documentMetadata.first.collectionName, 'Engineering');
    });

    test('withNewExtraction preserves collection info on re-ingestion', () {
      final initial = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Old',
            description: 'Old desc',
            sourceDocumentId: 'doc-1',
          ),
        ],
        documentMetadata: [
          DocumentMetadata(
            documentId: 'doc-1',
            title: 'Doc 1',
            updatedAt: '2025-01-01',
            ingestedAt: DateTime.utc(2025),
            collectionId: 'col-1',
            collectionName: 'Engineering',
          ),
        ],
      );

      final result = ExtractionResult(
        concepts: [
          Concept(
            id: 'c2',
            name: 'New',
            description: 'New desc',
            sourceDocumentId: '',
          ),
        ],
        relationships: const [],
        quizItems: [],
      );

      // Re-ingest without supplying collection info (e.g. sync)
      final updated = initial.withNewExtraction(
        result,
        documentId: 'doc-1',
        documentTitle: 'Doc 1',
        updatedAt: '2025-01-02',
      );

      // Collection info should be preserved from the existing metadata
      expect(updated.documentMetadata.first.collectionId, 'col-1');
      expect(updated.documentMetadata.first.collectionName, 'Engineering');
    });

    test('withUpdatedQuizItem replaces the right item', () {
      final graph = KnowledgeGraph(
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q1?',
            answer: 'A1.',
          ),
          QuizItem.newCard(
            id: 'q2',
            conceptId: 'c2',
            question: 'Q2?',
            answer: 'A2.',
          ),
        ],
      );

      final updated = graph.quizItems.first.withReview(
        easeFactor: 2.6,
        interval: 1,
        repetitions: 1,
        nextReview: DateTime.utc(2025, 1, 2),
      );

      final newGraph = graph.withUpdatedQuizItem(updated);

      expect(newGraph.quizItems.length, 2);
      expect(newGraph.quizItems.first.repetitions, 1);
      expect(newGraph.quizItems.last.repetitions, 0);
    });

    test('withTopic adds a new topic', () {
      final graph = KnowledgeGraph();
      final topic = Topic(
        id: 'topic-1',
        name: 'Agent Skills',
        documentIds: {'doc-1', 'doc-2'},
        createdAt: DateTime.utc(2026, 2, 18),
      );

      final updated = graph.withTopic(topic);

      expect(updated.topics, hasLength(1));
      expect(updated.topics.first.id, 'topic-1');
      expect(updated.topics.first.documentIds, hasLength(2));
    });

    test('withTopic upserts existing topic by ID', () {
      final topic1 = Topic(
        id: 'topic-1',
        name: 'Version 1',
        createdAt: DateTime.utc(2026, 2, 18),
      );
      final graph = KnowledgeGraph(topics: [topic1]);

      final topic1Updated = Topic(
        id: 'topic-1',
        name: 'Version 2',
        documentIds: {'doc-1'},
        createdAt: DateTime.utc(2026, 2, 18),
      );

      final updated = graph.withTopic(topic1Updated);

      expect(updated.topics, hasLength(1));
      expect(updated.topics.first.name, 'Version 2');
      expect(updated.topics.first.documentIds, hasLength(1));
    });

    test('withoutTopic removes topic by ID', () {
      final graph = KnowledgeGraph(
        topics: [
          Topic(
            id: 'topic-1',
            name: 'Keep',
            createdAt: DateTime.utc(2026, 2, 18),
          ),
          Topic(
            id: 'topic-2',
            name: 'Remove',
            createdAt: DateTime.utc(2026, 2, 18),
          ),
        ],
      );

      final updated = graph.withoutTopic('topic-2');

      expect(updated.topics, hasLength(1));
      expect(updated.topics.first.id, 'topic-1');
    });

    test('topics survive withNewExtraction', () {
      final topic = Topic(
        id: 'topic-1',
        name: 'Persisted Topic',
        createdAt: DateTime.utc(2026, 2, 18),
      );
      final graph = KnowledgeGraph(topics: [topic]);

      final result = ExtractionResult(
        concepts: [
          Concept(
            id: 'c1',
            name: 'C1',
            description: 'Desc',
            sourceDocumentId: '',
          ),
        ],
        relationships: const [],
        quizItems: [],
      );

      final updated = graph.withNewExtraction(
        result,
        documentId: 'doc-1',
        documentTitle: 'Doc 1',
        updatedAt: '2025-01-01',
      );

      expect(updated.topics, hasLength(1));
      expect(updated.topics.first.id, 'topic-1');
    });

    test('topics survive withUpdatedQuizItem', () {
      final topic = Topic(
        id: 'topic-1',
        name: 'Persisted',
        createdAt: DateTime.utc(2026, 2, 18),
      );
      final graph = KnowledgeGraph(
        topics: [topic],
        quizItems: [
          QuizItem.newCard(
            id: 'q1',
            conceptId: 'c1',
            question: 'Q?',
            answer: 'A.',
          ),
        ],
      );

      final updated = graph.quizItems.first.withReview(
        easeFactor: 2.6,
        interval: 1,
        repetitions: 1,
        nextReview: DateTime.utc(2025, 1, 2),
      );

      final newGraph = graph.withUpdatedQuizItem(updated);

      expect(newGraph.topics, hasLength(1));
      expect(newGraph.topics.first.id, 'topic-1');
    });

    test('topics round-trip through JSON', () {
      final graph = KnowledgeGraph(
        topics: [
          Topic(
            id: 'topic-1',
            name: 'Agent Skills',
            description: 'Course',
            documentIds: {'doc-1', 'doc-2'},
            createdAt: DateTime.utc(2026, 2, 18),
            lastIngestedAt: DateTime.utc(2026, 2, 18, 1),
          ),
        ],
      );

      final jsonStr = jsonEncode(graph.toJson());
      final restored = KnowledgeGraph.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );

      expect(restored.topics, hasLength(1));
      expect(restored.topics.first.id, 'topic-1');
      expect(restored.topics.first.name, 'Agent Skills');
      expect(restored.topics.first.documentIds, hasLength(2));
    });

    test('fromJson handles missing topics field (backward compat)', () {
      final json = {
        'concepts': <dynamic>[],
        'relationships': <dynamic>[],
        'quizItems': <dynamic>[],
        'documentMetadata': <dynamic>[],
      };

      final graph = KnowledgeGraph.fromJson(json);

      expect(graph.topics, isEmpty);
    });
  });
}
