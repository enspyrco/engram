import 'package:engram/src/models/knowledge_gap.dart';
import 'package:engram/src/models/recommendation.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PredictedEdge', () {
    test('JSON round-trip preserves all fields', () {
      const edge = PredictedEdge(
        fromConceptName: 'Neural Networks',
        toConceptName: 'Gradient Descent',
        type: RelationshipType.prerequisite,
        confidence: 0.85,
      );

      final json = edge.toJson();
      final restored = PredictedEdge.fromJson(json);

      expect(restored.fromConceptName, edge.fromConceptName);
      expect(restored.toConceptName, edge.toConceptName);
      expect(restored.type, edge.type);
      expect(restored.confidence, edge.confidence);
    });

    test('fromJson defaults unknown type to relatedTo', () {
      final edge = PredictedEdge.fromJson({
        'fromConceptName': 'A',
        'toConceptName': 'B',
        'type': 'unknownType',
        'confidence': 0.5,
      });

      expect(edge.type, RelationshipType.relatedTo);
    });

    test('equality based on names and type', () {
      const edge1 = PredictedEdge(
        fromConceptName: 'A',
        toConceptName: 'B',
        type: RelationshipType.analogy,
        confidence: 0.5,
      );
      const edge2 = PredictedEdge(
        fromConceptName: 'A',
        toConceptName: 'B',
        type: RelationshipType.analogy,
        confidence: 0.9, // different confidence
      );

      expect(edge1, equals(edge2));
    });
  });

  group('Recommendation', () {
    final testGap = KnowledgeGap(
      type: GapType.clusterIsolation,
      description: 'Test gap',
      severity: 0.7,
      bridgePotential: 0.8,
    );

    test('JSON round-trip preserves all fields', () {
      final rec = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Advanced ML',
        gap: testGap,
        score: 0.85,
        reasoning: 'Good bridge document',
        searchSnippet: 'ML connects to...',
        collectionId: 'col-1',
        collectionName: 'Engineering',
        predictedNewEdges: const [
          PredictedEdge(
            fromConceptName: 'ML',
            toConceptName: 'Stats',
            type: RelationshipType.prerequisite,
            confidence: 0.9,
          ),
        ],
      );

      final json = rec.toJson();
      final restored = Recommendation.fromJson(json);

      expect(restored.documentId, rec.documentId);
      expect(restored.documentTitle, rec.documentTitle);
      expect(restored.gap.type, rec.gap.type);
      expect(restored.score, rec.score);
      expect(restored.reasoning, rec.reasoning);
      expect(restored.searchSnippet, rec.searchSnippet);
      expect(restored.collectionId, rec.collectionId);
      expect(restored.collectionName, rec.collectionName);
      expect(restored.predictedNewEdges, hasLength(1));
      expect(restored.predictedNewEdges.first.fromConceptName, 'ML');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'documentId': 'doc-1',
        'documentTitle': 'Doc',
        'gap': testGap.toJson(),
        'score': 0.5,
        'reasoning': 'Decent fit',
      };

      final rec = Recommendation.fromJson(json);

      expect(rec.searchSnippet, isNull);
      expect(rec.collectionId, isNull);
      expect(rec.collectionName, isNull);
      expect(rec.predictedNewEdges, isEmpty);
    });

    test('equality based on documentId', () {
      final rec1 = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Title A',
        gap: testGap,
        score: 0.5,
        reasoning: 'Reason A',
      );
      final rec2 = Recommendation(
        documentId: 'doc-1',
        documentTitle: 'Title B', // different title
        gap: testGap,
        score: 0.9, // different score
        reasoning: 'Reason B',
      );

      expect(rec1, equals(rec2));
      expect(rec1.hashCode, rec2.hashCode);
    });
  });
}
