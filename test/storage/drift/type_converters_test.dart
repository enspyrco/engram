import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/storage/drift/type_converters.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

void main() {
  group('IListStringConverter', () {
    const converter = IListStringConverter();

    test('round-trips a non-empty list', () {
      final original = IList(const ['flutter', 'dart', 'sqlite']);
      final sql = converter.toSql(original);
      final restored = converter.fromSql(sql);
      expect(restored, original);
    });

    test('round-trips an empty list', () {
      final original = IList<String>(const []);
      final sql = converter.toSql(original);
      final restored = converter.fromSql(sql);
      expect(restored, original);
    });

    test('handles special characters in strings', () {
      final original = IList(const [
        'has "quotes"',
        'has\\backslash',
        'has,comma',
      ]);
      final sql = converter.toSql(original);
      final restored = converter.fromSql(sql);
      expect(restored, original);
    });

    test('toSql produces valid JSON array', () {
      final original = IList(const ['a', 'b']);
      final sql = converter.toSql(original);
      expect(sql, '["a","b"]');
    });
  });

  group('RelationshipTypeConverter', () {
    const converter = RelationshipTypeConverter();

    test('round-trips every RelationshipType value', () {
      for (final type in RelationshipType.values) {
        final sql = converter.toSql(type);
        final restored = converter.fromSql(sql);
        expect(restored, type, reason: '${type.name} should round-trip');
      }
    });

    test('falls back to relatedTo for unknown values', () {
      final result = converter.fromSql('unknownType');
      expect(result, RelationshipType.relatedTo);
    });

    test('toSql produces the enum name', () {
      expect(converter.toSql(RelationshipType.prerequisite), 'prerequisite');
      expect(converter.toSql(RelationshipType.composition), 'composition');
    });
  });
}
