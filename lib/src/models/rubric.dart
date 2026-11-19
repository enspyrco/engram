import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

/// Grading criteria a blind assessor checks a learner's free-text answer
/// against ("names both terms", "explains why X is needed").
///
/// Always [minCriteria]-[maxCriteria] non-blank criteria. Anything else is not
/// a rubric: the card has none and falls back to self-rating.
@immutable
final class Rubric {
  const Rubric._(this.criteria);

  static const minCriteria = 2;
  static const maxCriteria = 4;

  /// Reads a rubric from stored JSON or Claude's tool output.
  ///
  /// Returns null unless [raw] is a list of [minCriteria]-[maxCriteria]
  /// non-blank strings, so a malformed optional field drops the rubric
  /// instead of failing the card.
  static Rubric? parse(Object? raw) {
    if (raw is! List) return null;
    final criteria = <String>[];
    for (final criterion in raw) {
      if (criterion is! String || criterion.trim().isEmpty) return null;
      criteria.add(criterion.trim());
    }
    if (criteria.length < minCriteria || criteria.length > maxCriteria) {
      return null;
    }
    return Rubric._(criteria.lock);
  }

  final IList<String> criteria;

  List<String> toJson() => criteria.toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Rubric && other.criteria == criteria;

  @override
  int get hashCode => criteria.hashCode;

  @override
  String toString() => 'Rubric($criteria)';
}
