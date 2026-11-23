import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/models/assessment.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

final _quote = Quote.find('some quoted words', 'quoted words')!;

IList<CriterionJudgement> _judged(List<CriterionVerdict> verdicts) =>
    [
      for (final (i, v) in verdicts.indexed)
        switch (v) {
          CriterionVerdict.met => CriterionJudgement.met(
            'criterion $i',
            _quote,
          ),
          CriterionVerdict.partial => CriterionJudgement.partial(
            'criterion $i',
            _quote,
          ),
          CriterionVerdict.missed => CriterionJudgement.missed('criterion $i'),
        },
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
        ratingFor(
          _judged([met, met]),
          misconceptions: [Misconception('wrong claim', _quote)].lock,
        ),
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

  group('Quote.find', () {
    const answer =
        'Precision and recall. You normalize so that  big counts\n'
        "don't swamp small ones; the result is incorrect otherwise.";

    test('ignores case, whitespace runs and punctuation', () {
      expect(Quote.find(answer, 'precision AND recall'), isNotNull);
      expect(Quote.find(answer, 'so that big counts'), isNotNull);
      expect(Quote.find(answer, '"Precision and recall."'), isNotNull);
      expect(Quote.find(answer, 'recall you normalize'), isNotNull);
    });

    test('matches whole words only', () {
      expect(Quote.find(answer, 'is correct'), isNull);
      expect(Quote.find(answer, 'ecall. You'), isNull);
    });

    test('rejects a one-word quote unless it is the whole answer', () {
      expect(Quote.find(answer, 'precision'), isNull);
      expect(Quote.find('Mitochondria.', 'mitochondria'), isNotNull);
    });

    test('rejects words the answer does not contain', () {
      expect(Quote.find(answer, 'precision and accuracy'), isNull);
      expect(Quote.find(answer, '  ...  '), isNull);
    });

    test('keeps the text the grader wrote', () {
      expect(
        Quote.find(answer, ' Precision and recall ')!.text,
        'Precision and recall',
      );
    });
  });
}
