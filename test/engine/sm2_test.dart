import 'package:engram/src/engine/sm2.dart';
import 'package:test/test.dart';

void main() {
  group('sm2', () {
    test('first successful review gives interval of 1', () {
      final result = sm2(
        quality: 4,
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
      );

      expect(result.interval, 1);
      expect(result.repetitions, 1);
    });

    test('second successful review gives interval of 6', () {
      final result = sm2(
        quality: 4,
        easeFactor: 2.5,
        interval: 1,
        repetitions: 1,
      );

      expect(result.interval, 6);
      expect(result.repetitions, 2);
    });

    test('third successful review uses EF * interval', () {
      final result = sm2(
        quality: 4,
        easeFactor: 2.5,
        interval: 6,
        repetitions: 2,
      );

      expect(result.interval, 15); // 6 * 2.5 = 15
      expect(result.repetitions, 3);
    });

    test('quality < 3 resets repetitions and sets interval to 1', () {
      final result = sm2(
        quality: 2,
        easeFactor: 2.5,
        interval: 15,
        repetitions: 5,
      );

      expect(result.interval, 1);
      expect(result.repetitions, 0);
    });

    test('quality 0 resets and decreases ease factor', () {
      final result = sm2(
        quality: 0,
        easeFactor: 2.5,
        interval: 10,
        repetitions: 3,
      );

      expect(result.interval, 1);
      expect(result.repetitions, 0);
      expect(result.easeFactor, lessThan(2.5));
    });

    test('perfect quality 5 increases ease factor', () {
      final result = sm2(
        quality: 5,
        easeFactor: 2.5,
        interval: 6,
        repetitions: 2,
      );

      expect(result.easeFactor, greaterThan(2.5));
    });

    test('quality 3 decreases ease factor', () {
      final result = sm2(
        quality: 3,
        easeFactor: 2.5,
        interval: 6,
        repetitions: 2,
      );

      expect(result.easeFactor, lessThan(2.5));
    });

    test('ease factor never drops below 1.3', () {
      // Repeated failures should floor at 1.3
      var ef = 2.5;
      var interval = 10;
      var repetitions = 3;

      for (var i = 0; i < 20; i++) {
        final result = sm2(
          quality: 0,
          easeFactor: ef,
          interval: interval,
          repetitions: repetitions,
        );
        ef = result.easeFactor;
        interval = result.interval;
        repetitions = result.repetitions;
      }

      expect(ef, greaterThanOrEqualTo(1.3));
    });

    test('SM-2 formula progression: 1 → 6 → EF*interval', () {
      // Simulate a series of quality-4 reviews
      var ef = 2.5;
      var interval = 0;
      var repetitions = 0;

      // Review 1
      var result = sm2(
        quality: 4,
        easeFactor: ef,
        interval: interval,
        repetitions: repetitions,
      );
      expect(result.interval, 1);
      ef = result.easeFactor;
      interval = result.interval;
      repetitions = result.repetitions;

      // Review 2
      result = sm2(
        quality: 4,
        easeFactor: ef,
        interval: interval,
        repetitions: repetitions,
      );
      expect(result.interval, 6);
      ef = result.easeFactor;
      interval = result.interval;
      repetitions = result.repetitions;

      // Review 3: should be interval * ef
      result = sm2(
        quality: 4,
        easeFactor: ef,
        interval: interval,
        repetitions: repetitions,
      );
      expect(result.interval, (6 * ef).round());
    });
  });
}
