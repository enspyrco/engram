import 'dart:convert';

import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/models/assessment.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

void main() {
  const met = CriterionVerdict.met;
  const partial = CriterionVerdict.partial;
  const missed = CriterionVerdict.missed;

  group('RatingPolicy.nothingMissed', () {
    FsrsRating rate(
      List<CriterionVerdict> verdicts, {
      bool misconceived = false,
    }) => RatingPolicy.nothingMissed.rate(verdicts, misconceived: misconceived);

    test('every criterion met is good', () {
      expect(rate([met, met, met]), FsrsRating.good);
    });

    test('nothing missed and something partial is hard', () {
      expect(rate([met, met, met, partial]), FsrsRating.hard);
      expect(rate([partial, partial]), FsrsRating.hard);
    });

    test('any missed criterion is again', () {
      expect(rate([met, missed]), FsrsRating.again);
      expect(rate([met, met, met, missed]), FsrsRating.again);
      expect(rate([partial, missed]), FsrsRating.again);
    });

    test('any misconception is again, even with every criterion met', () {
      expect(rate([met, met], misconceived: true), FsrsRating.again);
      expect(rate([met, partial], misconceived: true), FsrsRating.again);
    });

    test('never easy', () {
      expect(rate([met]), isNot(FsrsRating.easy));
      expect(rate([met, met, met, met]), isNot(FsrsRating.easy));
    });

    test('no verdicts is again', () {
      expect(rate([]), FsrsRating.again);
    });
  });

  group('AnswerText', () {
    test('tokens are runs of non-whitespace with offsets', () {
      final answer = AnswerText.of('  Paris,\n\tthe  capital. ');
      expect(answer.tokens.map((t) => t.text), ['Paris,', 'the', 'capital.']);
      expect(answer.tokens.map((t) => (t.start, t.end)), [
        (2, 8),
        (10, 13),
        (15, 23),
      ]);
      expect(answer.text, '  Paris,\n\tthe  capital. ');
    });

    test('a blank answer has no tokens', () {
      expect(AnswerText.of(' \n\t ').isBlank, isTrue);
      expect(AnswerText.of('').isBlank, isTrue);
      expect(AnswerText.of('-5').isBlank, isFalse);
    });
  });

  group('Span.of', () {
    final answer = AnswerText.of('Paris is wrong.  Paris is\ncorrect.');
    // Tokens: 0 Paris, 1 is, 2 wrong., 3 Paris, 4 is, 5 correct.

    test('cites the tokens at the position, spacing kept', () {
      final span = Span.of(answer, 3, ['Paris', 'is', 'correct.'])!;
      expect((span.start, span.end, span.length), (3, 6, 3));
      expect(span.text, 'Paris is\ncorrect.');
      expect(answer.text.substring(span.charStart, span.charEnd), span.text);
    });

    test('the position says which occurrence is meant', () {
      expect(Span.of(answer, 0, ['Paris', 'is'])!.start, 0);
      expect(Span.of(answer, 3, ['Paris', 'is'])!.start, 3);
    });

    test('a miscounted position resolves to nothing', () {
      expect(Span.of(answer, 1, ['Paris', 'is']), isNull);
      expect(Span.of(answer, 4, ['Paris', 'is', 'correct.']), isNull);
    });

    test('tokens are compared exactly, without normalizing', () {
      expect(Span.of(answer, 5, ['correct']), isNull);
      expect(Span.of(answer, 0, ['paris']), isNull);
      expect(Span.of(answer, 5, ['correct.']), isNotNull);
    });

    test('one token is enough', () {
      expect(Span.of(AnswerText.of('-5'), 0, ['-5'])!.text, '-5');
    });

    test('a citation past either end, or of nothing, resolves to nothing', () {
      expect(Span.of(answer, -1, ['Paris']), isNull);
      expect(Span.of(answer, 5, ['correct.', 'more']), isNull);
      expect(Span.of(answer, 6, ['x']), isNull);
      expect(Span.of(answer, 0, []), isNull);
    });

    test('a start near the int maximum resolves to nothing, not a throw', () {
      // 2^63 - 1, written so dart2js accepts the literal too.
      const max = (1 << 62) - 1 + (1 << 62);
      expect(Span.of(answer, max, ['Paris']), isNull);
      expect(Span.of(answer, max - 1, ['Paris', 'is']), isNull);
    });

    test('spans of different words are not equal', () {
      final paris = Span.of(AnswerText.of('Paris'), 0, ['Paris']);
      final london = Span.of(AnswerText.of('London'), 0, ['London']);
      expect(paris, isNot(london));
      expect(paris, Span.of(AnswerText.of('Paris'), 0, ['Paris']));
    });
  });

  test('the tokenizer fingerprint records each token with its offsets', () {
    final entries =
        jsonDecode(AnswerText.tokenizerFingerprint)
            as List; // cast-ok: test decodes what the model encoded
    expect(entries, isNotEmpty);
    expect(entries, everyElement(hasLength(3)));
    expect(
      entries.map((e) => (e as List).first),
      contains('東京は首都'),
    ); // cast-ok: each entry is a list, checked above
  });

  group('scheduledRating', () {
    final span = Span.of(AnswerText.of('Paris'), 0, ['Paris'])!;

    test('a failed grading or a blank answer writes again', () {
      expect(
        const GradingFailed(
          GradingFailure.unresolvedCitation,
          '',
        ).scheduledRating,
        FsrsRating.again,
      );
      expect(const Unanswered().scheduledRating, FsrsRating.again);
    });

    test('a graded answer writes its policy rating', () {
      final receipt = AssessmentReceipt(
        judgements:
            [
              CriterionJudgement.met('a', span),
              CriterionJudgement.met('b', span),
            ].lock,
        misconceptions: const IListConst([]),
        feedback: '',
        graderVersion: (
          prompt: PromptDigest.of([1]),
          model: GraderModel.opus55,
          policy: RatingPolicy.nothingMissed,
        ),
      );
      expect(Graded(receipt).scheduledRating, FsrsRating.good);
    });
  });

  test('PromptDigest changes with any byte of the prompt', () {
    final a = PromptDigest.of('grade this'.codeUnits);
    expect(PromptDigest.of('grade this'.codeUnits), a);
    expect(PromptDigest.of('grade this.'.codeUnits), isNot(a));
    expect(a.hex, hasLength(12));
  });

  test('GraderModel.parse reads only Claude model ids', () {
    expect(GraderModel.parse('claude-sonnet-5-5'), isNotNull);
    expect(GraderModel.parse('claude-opus-5-5'), GraderModel.opus55);
    expect(GraderModel.parse(''), isNull);
    expect(GraderModel.parse('gpt-6'), isNull);
    expect(GraderModel.parse('claude-opus 5'), isNull);
  });

  test('CriterionVerdict.parse reads only known names', () {
    expect(CriterionVerdict.parse('met'), met);
    expect(CriterionVerdict.parse('partial'), partial);
    expect(CriterionVerdict.parse('MET'), isNull);
    expect(CriterionVerdict.parse(1), isNull);
    expect(CriterionVerdict.parse(null), isNull);
  });
}
