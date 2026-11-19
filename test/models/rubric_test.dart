import 'package:engram/src/models/rubric.dart';
import 'package:test/test.dart';

void main() {
  group('Rubric.parse', () {
    test('reads 2-4 criteria, trimmed', () {
      final rubric = Rubric.parse([' names both terms ', 'explains why']);
      expect(rubric?.criteria, ['names both terms', 'explains why']);
      expect(rubric?.toJson(), ['names both terms', 'explains why']);
    });

    test('accepts the bounds', () {
      expect(Rubric.parse(['a', 'b']), isNotNull);
      expect(Rubric.parse(['a', 'b', 'c', 'd']), isNotNull);
    });

    test('returns null for too few or too many criteria', () {
      expect(Rubric.parse(<String>[]), isNull);
      expect(Rubric.parse(['only one']), isNull);
      expect(Rubric.parse(['a', 'b', 'c', 'd', 'e']), isNull);
    });

    test('returns null for malformed input instead of throwing', () {
      expect(Rubric.parse(null), isNull);
      expect(Rubric.parse('names both terms'), isNull);
      expect(Rubric.parse(['names both terms', 7]), isNull);
      expect(Rubric.parse(['names both terms', '   ']), isNull);
    });

    test('equal criteria make equal rubrics', () {
      expect(Rubric.parse(['a', 'b']), Rubric.parse(['a', 'b']));
      expect(Rubric.parse(['a', 'b']), isNot(Rubric.parse(['b', 'a'])));
    });
  });
}
