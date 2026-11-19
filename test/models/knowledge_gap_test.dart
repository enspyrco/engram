import 'package:engram/src/models/knowledge_gap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KnowledgeGap', () {
    test('JSON round-trip preserves all fields', () {
      final gap = KnowledgeGap(
        type: GapType.clusterIsolation,
        description: 'Clusters A and B have no cross-edges',
        severity: 0.8,
        bridgePotential: 0.9,
        involvedConceptIds: ['c1', 'c2', 'c3'],
        involvedClusterLabels: ['Cluster A', 'Cluster B'],
        suggestedSearchTerms: ['concept A', 'concept B bridge'],
      );

      final json = gap.toJson();
      final restored = KnowledgeGap.fromJson(json);

      expect(restored.type, gap.type);
      expect(restored.description, gap.description);
      expect(restored.severity, gap.severity);
      expect(restored.bridgePotential, gap.bridgePotential);
      expect(restored.involvedConceptIds, gap.involvedConceptIds);
      expect(restored.involvedClusterLabels, gap.involvedClusterLabels);
      expect(restored.suggestedSearchTerms, gap.suggestedSearchTerms);
    });

    test('fromJson handles missing optional lists', () {
      final json = {
        'type': 'structuralThinness',
        'description': 'Concept X has only one connection',
        'severity': 0.5,
        'bridgePotential': 0.3,
      };

      final gap = KnowledgeGap.fromJson(json);

      expect(gap.involvedConceptIds, isEmpty);
      expect(gap.involvedClusterLabels, isEmpty);
      expect(gap.suggestedSearchTerms, isEmpty);
    });

    test(
      'equality based on type + description + severity + bridgePotential',
      () {
        final gap1 = KnowledgeGap(
          type: GapType.clusterIsolation,
          description: 'Same gap',
          severity: 0.7,
          bridgePotential: 0.5,
        );

        final gap2 = KnowledgeGap(
          type: GapType.clusterIsolation,
          description: 'Same gap',
          severity: 0.7,
          bridgePotential: 0.5,
          involvedConceptIds: ['c1'], // different concepts — still equal
        );

        expect(gap1, equals(gap2));
        expect(gap1.hashCode, gap2.hashCode);
      },
    );

    test('different bridgePotential makes gaps unequal', () {
      final gap1 = KnowledgeGap(
        type: GapType.clusterIsolation,
        description: 'Same gap',
        severity: 0.7,
        bridgePotential: 0.5,
      );

      final gap2 = KnowledgeGap(
        type: GapType.clusterIsolation,
        description: 'Same gap',
        severity: 0.7,
        bridgePotential: 0.9,
      );

      expect(gap1, isNot(equals(gap2)));
    });

    test('different type or description are not equal', () {
      final gap1 = KnowledgeGap(
        type: GapType.clusterIsolation,
        description: 'Gap A',
        severity: 0.7,
        bridgePotential: 0.5,
      );

      final gap2 = KnowledgeGap(
        type: GapType.structuralThinness,
        description: 'Gap A',
        severity: 0.7,
        bridgePotential: 0.5,
      );

      expect(gap1, isNot(equals(gap2)));
    });

    test('all GapType values round-trip through JSON', () {
      for (final type in GapType.values) {
        final gap = KnowledgeGap(
          type: type,
          description: 'test',
          severity: 0.5,
          bridgePotential: 0.5,
        );
        final restored = KnowledgeGap.fromJson(gap.toJson());
        expect(restored.type, type);
      }
    });

    test('toString includes type, severity, and description', () {
      final gap = KnowledgeGap(
        type: GapType.criticalBottleneck,
        description: 'Concept X is a bottleneck',
        severity: 0.9,
        bridgePotential: 0.6,
      );

      final str = gap.toString();
      expect(str, contains('criticalBottleneck'));
      expect(str, contains('0.9'));
      expect(str, contains('Concept X is a bottleneck'));
    });
  });
}
