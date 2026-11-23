import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/models/assessment.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

IList<CriterionJudgement> _judged(List<CriterionVerdict> verdicts) =>
    [
      for (final (i, v) in verdicts.indexed)
        CriterionJudgement(
          criterion: 'criterion $i',
          verdict: v,
          evidence: v == CriterionVerdict.missed ? null : 'quote',
        ),
    ].lock;

void main() {
  const met = CriterionVerdict.met;
  const partial = CriterionVerdict.partial;
  const missed = CriterionVerdict.missed;

  group('ratingFor', () {
    test('every criterion met is good', () {
      expect(ratingFor(_judged([met, met, met])), FsrsRating.good);
    });

    test('a misconception caps a full answer at hard', () {
      expect(
        ratingFor(_judged([met, met]), misconceptions: ['wrong claim'].lock),
        FsrsRating.hard,
      );
    });

    test('half the credit is hard, less is again', () {
      expect(ratingFor(_judged([met, missed])), FsrsRating.hard);
      expect(ratingFor(_judged([partial, partial])), FsrsRating.hard);
      expect(ratingFor(_judged([partial, missed])), FsrsRating.again);
      expect(ratingFor(_judged([met, missed, missed])), FsrsRating.again);
    });

    test('one partial keeps a nearly full answer at hard', () {
      expect(ratingFor(_judged([met, met, met, partial])), FsrsRating.hard);
    });

    test('never easy', () {
      for (final verdicts in [
        [met],
        [met, met, met, met],
      ]) {
        expect(ratingFor(_judged(verdicts)), isNot(FsrsRating.easy));
      }
    });

    test('no judgements is again', () {
      expect(ratingFor(const IListConst([])), FsrsRating.again);
    });
  });

  test('CriterionVerdict.parse reads only known names', () {
    expect(CriterionVerdict.parse('met'), met);
    expect(CriterionVerdict.parse('partial'), partial);
    expect(CriterionVerdict.parse('MET'), isNull);
    expect(CriterionVerdict.parse(1), isNull);
    expect(CriterionVerdict.parse(null), isNull);
  });
}
