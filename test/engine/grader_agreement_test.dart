import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/engine/grader_agreement.dart';
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
}
