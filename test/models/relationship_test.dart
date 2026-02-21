import 'package:engram/src/models/relationship.dart';
import 'package:test/test.dart';

void main() {
  group('RelationshipType.inferFromLabel', () {
    test('infers prerequisite from "depends on"', () {
      expect(
        RelationshipType.inferFromLabel('depends on'),
        RelationshipType.prerequisite,
      );
    });

    test('infers prerequisite from "requires"', () {
      expect(
        RelationshipType.inferFromLabel('requires'),
        RelationshipType.prerequisite,
      );
    });

    test('infers prerequisite from "prerequisite" substring', () {
      expect(
        RelationshipType.inferFromLabel('is a prerequisite for'),
        RelationshipType.prerequisite,
      );
    });

    test('infers prerequisite from "builds on"', () {
      expect(
        RelationshipType.inferFromLabel('builds on'),
        RelationshipType.prerequisite,
      );
    });

    test('infers prerequisite from "assumes"', () {
      expect(
        RelationshipType.inferFromLabel('assumes knowledge of'),
        RelationshipType.prerequisite,
      );
    });

    test('infers prerequisite case-insensitively', () {
      expect(
        RelationshipType.inferFromLabel('DEPENDS ON'),
        RelationshipType.prerequisite,
      );
    });

    test('infers generalization from "type of"', () {
      expect(
        RelationshipType.inferFromLabel('is a type of'),
        RelationshipType.generalization,
      );
    });

    test('infers composition from "part of"', () {
      expect(
        RelationshipType.inferFromLabel('is part of'),
        RelationshipType.composition,
      );
    });

    test('infers composition from "composed of"', () {
      expect(
        RelationshipType.inferFromLabel('composed of'),
        RelationshipType.composition,
      );
    });

    test('infers enables from "enables"', () {
      expect(
        RelationshipType.inferFromLabel('enables'),
        RelationshipType.enables,
      );
    });

    test('infers analogy from "analogous"', () {
      expect(
        RelationshipType.inferFromLabel('analogous to'),
        RelationshipType.analogy,
      );
    });

    test('infers contrast from "contrast"', () {
      expect(
        RelationshipType.inferFromLabel('contrasts with'),
        RelationshipType.contrast,
      );
    });

    test('falls back to relatedTo for unknown labels', () {
      expect(
        RelationshipType.inferFromLabel('related to'),
        RelationshipType.relatedTo,
      );
      expect(
        RelationshipType.inferFromLabel('some random label'),
        RelationshipType.relatedTo,
      );
    });
  });

  group('RelationshipType.tryParse', () {
    test('parses all valid enum names', () {
      for (final type in RelationshipType.values) {
        expect(RelationshipType.tryParse(type.name), type);
      }
    });

    test('returns null for unknown strings', () {
      expect(RelationshipType.tryParse('unknownType'), isNull);
      expect(RelationshipType.tryParse(''), isNull);
    });
  });

  group('RelationshipType.isDependency', () {
    test('prerequisite is a dependency', () {
      expect(RelationshipType.prerequisite.isDependency, isTrue);
    });

    test('all other types are not dependencies', () {
      for (final type in RelationshipType.values) {
        if (type == RelationshipType.prerequisite) continue;
        expect(
          type.isDependency,
          isFalse,
          reason: '$type should not be a dependency',
        );
      }
    });
  });

  group('Relationship.resolvedType', () {
    test('returns explicit type when set', () {
      const rel = Relationship(
        id: 'r1',
        fromConceptId: 'a',
        toConceptId: 'b',
        label: 'related to',
        type: RelationshipType.prerequisite,
      );
      expect(rel.resolvedType, RelationshipType.prerequisite);
    });

    test('infers type from label when type is null', () {
      const rel = Relationship(
        id: 'r1',
        fromConceptId: 'a',
        toConceptId: 'b',
        label: 'depends on',
      );
      expect(rel.resolvedType, RelationshipType.prerequisite);
    });
  });

  group('Relationship.fromJson / toJson', () {
    test('round-trips with explicit type', () {
      const original = Relationship(
        id: 'r1',
        fromConceptId: 'a',
        toConceptId: 'b',
        label: 'depends on',
        description: 'A requires B',
        type: RelationshipType.prerequisite,
      );

      final json = original.toJson();
      expect(json['type'], 'prerequisite');

      final restored = Relationship.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.type, RelationshipType.prerequisite);
      expect(restored.resolvedType, RelationshipType.prerequisite);
      expect(restored.description, 'A requires B');
    });

    test('fromJson without type field infers from label', () {
      final json = {
        'id': 'r1',
        'fromConceptId': 'a',
        'toConceptId': 'b',
        'label': 'is a type of',
      };

      final rel = Relationship.fromJson(json);
      expect(rel.type, isNull);
      expect(rel.resolvedType, RelationshipType.generalization);
    });

    test('toJson normalizes legacy data by writing resolvedType', () {
      final json = {
        'id': 'r1',
        'fromConceptId': 'a',
        'toConceptId': 'b',
        'label': 'enables',
      };

      final rel = Relationship.fromJson(json);
      final output = rel.toJson();
      expect(output['type'], 'enables');
    });

    test('fromJson handles unknown type string gracefully', () {
      final json = {
        'id': 'r1',
        'fromConceptId': 'a',
        'toConceptId': 'b',
        'label': 'something',
        'type': 'unknownType',
      };

      final rel = Relationship.fromJson(json);
      expect(rel.type, RelationshipType.relatedTo);
    });

    test('round-trips all enum values', () {
      for (final type in RelationshipType.values) {
        final rel = Relationship(
          id: 'r-${type.name}',
          fromConceptId: 'a',
          toConceptId: 'b',
          label: type.name,
          type: type,
        );

        final json = rel.toJson();
        final restored = Relationship.fromJson(json);
        expect(restored.type, type, reason: 'Failed round-trip for $type');
      }
    });
  });
}
