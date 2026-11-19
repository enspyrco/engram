import 'package:engram/src/engine/recommendation_evaluation.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_gap.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/recommendation.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testGap = KnowledgeGap(
    type: GapType.clusterIsolation,
    description: 'Test gap',
    severity: 0.7,
    bridgePotential: 0.8,
  );

  group('evaluateRecommendation', () {
    test('no predicted edges returns zeroes and null accuracy', () {
      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Doc',
        gap: testGap,
        score: 0.8,
        reasoning: 'Good fit',
        predictedNewEdges: const [],
      );

      final result = evaluateRecommendation(
        recommendation: rec,
        graphBefore: KnowledgeGraph(),
        graphAfter: KnowledgeGraph(),
      );

      expect(result.matchedCount, 0);
      expect(result.missedCount, 0);
      expect(result.unexpectedCount, 0);
      expect(result.totalPredicted, 0);
      expect(result.accuracy, isNull);
    });

    test('all predicted edges match actual new edges', () {
      final graphBefore = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'Alpha',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'Beta',
            description: '',
            sourceDocumentId: 'd',
          ),
        ],
      );

      final graphAfter = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'Alpha',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'Beta',
            description: '',
            sourceDocumentId: 'd',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'a',
            toConceptId: 'b',
            label: 'depends on',
            type: RelationshipType.prerequisite,
          ),
        ],
      );

      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Doc',
        gap: testGap,
        score: 0.8,
        reasoning: 'Good fit',
        predictedNewEdges: const [
          PredictedEdge(
            fromConceptName: 'Alpha',
            toConceptName: 'Beta',
            type: RelationshipType.prerequisite,
            confidence: 0.9,
          ),
        ],
      );

      final result = evaluateRecommendation(
        recommendation: rec,
        graphBefore: graphBefore,
        graphAfter: graphAfter,
      );

      expect(result.matchedCount, 1);
      expect(result.missedCount, 0);
      expect(result.unexpectedCount, 0);
      expect(result.totalPredicted, 1);
      expect(result.accuracy, 1.0);
    });

    test('predicted edge that does not appear is counted as missed', () {
      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'Alpha',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'Beta',
            description: '',
            sourceDocumentId: 'd',
          ),
        ],
      );

      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Doc',
        gap: testGap,
        score: 0.8,
        reasoning: 'Good fit',
        predictedNewEdges: const [
          PredictedEdge(
            fromConceptName: 'Alpha',
            toConceptName: 'Beta',
            type: RelationshipType.analogy,
            confidence: 0.9,
          ),
        ],
      );

      final result = evaluateRecommendation(
        recommendation: rec,
        graphBefore: graph,
        graphAfter: graph, // no new edges
      );

      expect(result.matchedCount, 0);
      expect(result.missedCount, 1);
      expect(result.accuracy, 0.0);
    });

    test('actual new edges not predicted are counted as unexpected', () {
      final graphBefore = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'Alpha',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'Beta',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'c',
            name: 'Gamma',
            description: '',
            sourceDocumentId: 'd',
          ),
        ],
      );

      final graphAfter = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'Alpha',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'Beta',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'c',
            name: 'Gamma',
            description: '',
            sourceDocumentId: 'd',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'a',
            toConceptId: 'b',
            label: 'depends on',
            type: RelationshipType.prerequisite,
          ),
          const Relationship(
            id: 'r2',
            fromConceptId: 'b',
            toConceptId: 'c',
            label: 'enables',
            type: RelationshipType.enables,
          ),
        ],
      );

      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Doc',
        gap: testGap,
        score: 0.8,
        reasoning: 'Good fit',
        predictedNewEdges: const [
          PredictedEdge(
            fromConceptName: 'Alpha',
            toConceptName: 'Beta',
            type: RelationshipType.prerequisite,
            confidence: 0.9,
          ),
        ],
      );

      final result = evaluateRecommendation(
        recommendation: rec,
        graphBefore: graphBefore,
        graphAfter: graphAfter,
      );

      expect(result.matchedCount, 1);
      expect(result.missedCount, 0);
      expect(result.unexpectedCount, 1);
      expect(result.totalActualNew, 2);
      expect(result.accuracy, 1.0);
    });

    test('case-insensitive matching of concept names', () {
      final graphBefore = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'Neural Networks',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'Gradient Descent',
            description: '',
            sourceDocumentId: 'd',
          ),
        ],
      );

      final graphAfter = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'a',
            name: 'Neural Networks',
            description: '',
            sourceDocumentId: 'd',
          ),
          Concept(
            id: 'b',
            name: 'Gradient Descent',
            description: '',
            sourceDocumentId: 'd',
          ),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'a',
            toConceptId: 'b',
            label: 'requires',
            type: RelationshipType.prerequisite,
          ),
        ],
      );

      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Doc',
        gap: testGap,
        score: 0.8,
        reasoning: 'Match',
        predictedNewEdges: const [
          PredictedEdge(
            fromConceptName: 'neural networks', // lowercase
            toConceptName: 'gradient descent',
            type: RelationshipType.prerequisite,
            confidence: 0.9,
          ),
        ],
      );

      final result = evaluateRecommendation(
        recommendation: rec,
        graphBefore: graphBefore,
        graphAfter: graphAfter,
      );

      expect(result.matchedCount, 1);
      expect(result.accuracy, 1.0);
    });

    test('pre-existing edges are not counted as new', () {
      const existingEdge = Relationship(
        id: 'r-old',
        fromConceptId: 'a',
        toConceptId: 'b',
        label: 'related to',
        type: RelationshipType.relatedTo,
      );

      final graphBefore = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
        ],
        relationships: [existingEdge],
      );

      // graphAfter has the same edge + one new one
      final graphAfter = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
        ],
        relationships: [
          existingEdge,
          const Relationship(
            id: 'r-new',
            fromConceptId: 'a',
            toConceptId: 'b',
            label: 'analogy',
            type: RelationshipType.analogy,
          ),
        ],
      );

      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Doc',
        gap: testGap,
        score: 0.8,
        reasoning: 'Match',
        predictedNewEdges: const [
          PredictedEdge(
            fromConceptName: 'A',
            toConceptName: 'B',
            type: RelationshipType.analogy,
            confidence: 0.8,
          ),
        ],
      );

      final result = evaluateRecommendation(
        recommendation: rec,
        graphBefore: graphBefore,
        graphAfter: graphAfter,
      );

      expect(result.matchedCount, 1);
      expect(result.totalActualNew, 1);
    });

    test('mixed matched and missed predictions', () {
      final graphBefore = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
          Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
        ],
      );

      final graphAfter = KnowledgeGraph(
        concepts: [
          Concept(id: 'a', name: 'A', description: '', sourceDocumentId: 'd'),
          Concept(id: 'b', name: 'B', description: '', sourceDocumentId: 'd'),
          Concept(id: 'c', name: 'C', description: '', sourceDocumentId: 'd'),
        ],
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'a',
            toConceptId: 'b',
            label: 'related',
            type: RelationshipType.relatedTo,
          ),
          // a→c was predicted but not created
        ],
      );

      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Doc',
        gap: testGap,
        score: 0.8,
        reasoning: 'Partial match',
        predictedNewEdges: const [
          PredictedEdge(
            fromConceptName: 'A',
            toConceptName: 'B',
            type: RelationshipType.relatedTo,
            confidence: 0.9,
          ),
          PredictedEdge(
            fromConceptName: 'A',
            toConceptName: 'C',
            type: RelationshipType.enables,
            confidence: 0.5,
          ),
        ],
      );

      final result = evaluateRecommendation(
        recommendation: rec,
        graphBefore: graphBefore,
        graphAfter: graphAfter,
      );

      expect(result.matchedCount, 1);
      expect(result.missedCount, 1);
      expect(result.totalPredicted, 2);
      expect(result.accuracy, 0.5);
    });
  });

  group('RecommendationEvaluationResult serialization', () {
    test('fromJson/toJson round-trip preserves all fields', () {
      const original = RecommendationEvaluationResult(
        matchedCount: 3,
        missedCount: 1,
        unexpectedCount: 2,
        totalPredicted: 4,
        totalActualNew: 5,
        accuracy: 0.75,
      );

      final json = original.toJson();
      final restored = RecommendationEvaluationResult.fromJson(json);

      expect(restored.matchedCount, original.matchedCount);
      expect(restored.missedCount, original.missedCount);
      expect(restored.unexpectedCount, original.unexpectedCount);
      expect(restored.totalPredicted, original.totalPredicted);
      expect(restored.totalActualNew, original.totalActualNew);
      expect(restored.accuracy, original.accuracy);
    });

    test('fromJson/toJson round-trip with null accuracy', () {
      const original = RecommendationEvaluationResult(
        matchedCount: 0,
        missedCount: 0,
        unexpectedCount: 0,
        totalPredicted: 0,
        totalActualNew: 0,
        accuracy: null,
      );

      final json = original.toJson();
      final restored = RecommendationEvaluationResult.fromJson(json);

      expect(restored.accuracy, isNull);
      expect(restored.totalPredicted, 0);
    });
  });
}
