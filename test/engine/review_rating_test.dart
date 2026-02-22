import 'package:engram/src/engine/fsrs_engine.dart';
import 'package:engram/src/engine/review_rating.dart';
import 'package:test/test.dart';

void main() {
  group('ReviewRating', () {
    test('exhaustive switch covers both arms', () {
      // Compile-time guarantee: if either arm is missing, the analyzer errors.
      String describe(ReviewRating rating) => switch (rating) {
        Sm2Rating(:final quality) => 'sm2:$quality',
        FsrsReviewRating(:final rating) => 'fsrs:$rating',
      };

      expect(describe(const Sm2Rating(5)), 'sm2:5');
      expect(describe(const FsrsReviewRating(FsrsRating.good)), 'fsrs:FsrsRating.good');
    });
  });

  group('Sm2Rating', () {
    test('equality by quality value', () {
      expect(const Sm2Rating(3), equals(const Sm2Rating(3)));
      expect(const Sm2Rating(3), isNot(equals(const Sm2Rating(4))));
    });

    test('hashCode consistent with equality', () {
      expect(const Sm2Rating(5).hashCode, const Sm2Rating(5).hashCode);
    });

    test('toString includes quality', () {
      expect(const Sm2Rating(2).toString(), 'Sm2Rating(2)');
    });
  });

  group('FsrsReviewRating', () {
    test('equality by FsrsRating', () {
      expect(
        const FsrsReviewRating(FsrsRating.good),
        equals(const FsrsReviewRating(FsrsRating.good)),
      );
      expect(
        const FsrsReviewRating(FsrsRating.good),
        isNot(equals(const FsrsReviewRating(FsrsRating.hard))),
      );
    });

    test('hashCode consistent with equality', () {
      expect(
        const FsrsReviewRating(FsrsRating.easy).hashCode,
        const FsrsReviewRating(FsrsRating.easy).hashCode,
      );
    });

    test('toString includes rating', () {
      expect(
        const FsrsReviewRating(FsrsRating.again).toString(),
        'FsrsReviewRating(FsrsRating.again)',
      );
    });

    test('Sm2Rating and FsrsReviewRating are not equal', () {
      expect(
        const Sm2Rating(3),
        isNot(equals(const FsrsReviewRating(FsrsRating.good))),
      );
    });
  });
}
