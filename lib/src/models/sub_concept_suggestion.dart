import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import 'concept.dart';
import 'quiz_item.dart';

/// A single sub-concept entry within a split suggestion.
@immutable
class SubConceptEntry {
  SubConceptEntry({required this.concept, List<QuizItem> quizItems = const []})
    : quizItems = IList(quizItems);

  final Concept concept;
  final IList<QuizItem> quizItems;
}

/// Claude's suggestion for splitting a parent concept into sub-concepts.
@immutable
class SubConceptSuggestion {
  SubConceptSuggestion({
    List<SubConceptEntry> entries = const [],
    this.rejectedRubricCount = 0,
  }) : entries = IList(entries);

  final IList<SubConceptEntry> entries;

  /// Quiz items Claude gave a rubric that `Rubric.parse` rejected; see
  /// `ExtractionResult.rejectedRubricCount`.
  final int rejectedRubricCount;
}
