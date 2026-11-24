import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/engine/grader_agreement.dart';
import 'package:engram/src/models/assessment.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

void main() {
  const again = FsrsRating.again;
  const hard = FsrsRating.hard;
  const good = FsrsRating.good;
  const easy = FsrsRating.easy;

  test('counts exact, near, higher and lower ratings apart', () {
    final a = agreementOf([
      (human: good, grader: good),
      (human: hard, grader: good),
      (human: again, grader: good),
      (human: easy, grader: good),
    ]);

    expect(a.count, 4);
    expect(a.exact, 1);
    expect(a.withinOne, 3);
    expect(a.overRated, 2);
    expect(a.underRated, 1);
    expect(a.confusion[again]![good], 1);
    expect(a.confusion[good]![good], 1);
    expect(a.confusion[good]![again], 0);
  });

  test('no pairs is all zeros', () {
    final a = agreementOf(const []);
    expect(a.count, 0);
    expect(a.exact, 0);
    expect(a.confusion[easy]![again], 0);
  });

  test('lazy evidence counts one-token, over-half and reused citations', () {
    final answer = AnswerText.of('cells need energy from mitochondria daily');
    Span cite(int start, List<String> tokens) =>
        Span.of(answer, start, tokens)!;
    final whole = cite(0, answer.tokens.map((t) => t.text).toList());
    final receipt = AssessmentReceipt(
      judgements:
          [
            CriterionJudgement.met('a', cite(4, ['mitochondria'])),
            CriterionJudgement.met('b', whole),
            CriterionJudgement.partial('c', whole),
            const CriterionJudgement.missed('d'),
          ].lock,
      misconceptions:
          [
            Misconception('daily', cite(5, ['daily'])),
          ].lock,
      feedback: '',
      graderVersion: (
        prompt: PromptDigest.of([0]),
        model: GraderModel.opus55,
        policy: RatingPolicy.nothingMissed,
      ),
    );

    final lazy = lazyEvidenceOf(receipt, answer);
    expect(lazy.oneToken, 2);
    expect(lazy.overHalf, 2);
    expect(lazy.reused, 1);
  });

  test('a one-token answer counts as one token, not also as over half', () {
    final answer = AnswerText.of('Paris');
    final paris = Span.of(answer, 0, ['Paris'])!;
    final receipt = AssessmentReceipt(
      judgements:
          [
            CriterionJudgement.met('a', paris),
            CriterionJudgement.met('b', paris),
          ].lock,
      misconceptions: const IListConst([]),
      feedback: '',
      graderVersion: (
        prompt: PromptDigest.of([0]),
        model: GraderModel.opus55,
        policy: RatingPolicy.nothingMissed,
      ),
    );

    final lazy = lazyEvidenceOf(receipt, answer);
    expect(lazy.oneToken, 2);
    expect(lazy.overHalf, 0);
  });
}
