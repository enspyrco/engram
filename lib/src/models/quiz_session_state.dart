import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

import 'quiz_item.dart';
import 'session_mode.dart';

enum QuizPhase { idle, question, revealed, summary }

@immutable
class QuizSessionState {
  QuizSessionState({
    this.phase = QuizPhase.idle,
    List<QuizItem> items = const [],
    this.currentIndex = 0,
    List<int> ratings = const [],
    this.isComeback = false,
    this.sessionMode = SessionMode.full,
    this.daysSinceLastSession,
  }) : items = IList(items),
       ratings = IList(ratings);

  const QuizSessionState._raw({
    required this.phase,
    required this.items,
    required this.currentIndex,
    required this.ratings,
    required this.isComeback,
    required this.sessionMode,
    this.daysSinceLastSession,
  });

  final QuizPhase phase;
  final IList<QuizItem> items;
  final int currentIndex;
  final IList<int> ratings;
  final bool isComeback;
  final SessionMode sessionMode;
  final int? daysSinceLastSession;

  QuizItem? get currentItem =>
      currentIndex < items.length ? items[currentIndex] : null;

  int get totalItems => items.length;
  int get reviewedCount => ratings.length;
  int get correctCount => ratings.where((r) => r >= 3).length;

  double get correctPercent =>
      reviewedCount > 0 ? correctCount / reviewedCount * 100 : 0;

  bool get isComplete => currentIndex >= items.length && items.isNotEmpty;

  QuizSessionState copyWith({
    QuizPhase? phase,
    IList<QuizItem>? items,
    int? currentIndex,
    IList<int>? ratings,
    bool? isComeback,
    SessionMode? sessionMode,
    int? daysSinceLastSession,
  }) {
    return QuizSessionState._raw(
      phase: phase ?? this.phase,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      ratings: ratings ?? this.ratings,
      isComeback: isComeback ?? this.isComeback,
      sessionMode: sessionMode ?? this.sessionMode,
      daysSinceLastSession: daysSinceLastSession ?? this.daysSinceLastSession,
    );
  }
}
