import 'fsrs_engine.dart';

/// Rating submitted after a quiz review, dispatching to SM-2 or FSRS.
///
/// Sealed so that `switch` on [ReviewRating] is exhaustive — the compiler
/// enforces that both arms are handled. In Phase 3, removing [Sm2Rating]
/// will surface every call-site that still references SM-2.
sealed class ReviewRating {
  const ReviewRating();
}

/// SM-2 quality rating (0-5).
class Sm2Rating extends ReviewRating {
  const Sm2Rating(this.quality) : assert(quality >= 0 && quality <= 5);

  final int quality;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Sm2Rating && other.quality == quality;

  @override
  int get hashCode => quality.hashCode;

  @override
  String toString() => 'Sm2Rating($quality)';
}

/// FSRS 4-point rating.
class FsrsReviewRating extends ReviewRating {
  const FsrsReviewRating(this.rating);

  final FsrsRating rating;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FsrsReviewRating && other.rating == rating;

  @override
  int get hashCode => rating.hashCode;

  @override
  String toString() => 'FsrsReviewRating($rating)';
}
