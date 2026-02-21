import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../models/concept.dart';
import '../models/quiz_item.dart';
import '../models/relationship.dart';
import '../models/sub_concept_suggestion.dart';
import 'knowledge_graph_provider.dart';
import 'service_providers.dart';

enum SplitPhase { idle, loading, reviewing, applying, error }

@immutable
class SplitState {
  const SplitState({
    this.phase = SplitPhase.idle,
    this.parentConceptId,
    this.suggestion,
    this.selectedIndices = const {},
    this.errorMessage,
  });

  final SplitPhase phase;
  final String? parentConceptId;
  final SubConceptSuggestion? suggestion;
  final Set<int> selectedIndices;
  final String? errorMessage;

  SplitState copyWith({
    SplitPhase? phase,
    String? parentConceptId,
    SubConceptSuggestion? suggestion,
    Set<int>? selectedIndices,
    String? errorMessage,
  }) {
    return SplitState(
      phase: phase ?? this.phase,
      parentConceptId: parentConceptId ?? this.parentConceptId,
      suggestion: suggestion ?? this.suggestion,
      selectedIndices: selectedIndices ?? this.selectedIndices,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final splitConceptProvider = NotifierProvider<SplitConceptNotifier, SplitState>(
  SplitConceptNotifier.new,
);

class SplitConceptNotifier extends Notifier<SplitState> {
  @override
  SplitState build() => const SplitState();

  /// Ask Claude to suggest sub-concepts for the given concept.
  Future<void> requestSplit({
    required String conceptId,
    required String conceptName,
    required String conceptDescription,
    required String sourceDocumentId,
    required String quizQuestion,
    required String quizAnswer,
  }) async {
    state = SplitState(phase: SplitPhase.loading, parentConceptId: conceptId);

    try {
      final service = ref.read(extractionServiceProvider);
      final suggestion = await service.generateSubConcepts(
        parentConceptId: conceptId,
        parentName: conceptName,
        parentDescription: conceptDescription,
        quizQuestion: quizQuestion,
        quizAnswer: quizAnswer,
        sourceDocumentId: sourceDocumentId,
      );

      // Default: all sub-concepts selected
      final allIndices = {
        for (var i = 0; i < suggestion.entries.length; i++) i,
      };

      state = state.copyWith(
        phase: SplitPhase.reviewing,
        suggestion: suggestion,
        selectedIndices: allIndices,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        phase: SplitPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Toggle selection of a sub-concept by index.
  void toggleSubConcept(int index) {
    if (state.phase != SplitPhase.reviewing) return;
    final updated = Set<int>.from(state.selectedIndices);
    if (updated.contains(index)) {
      updated.remove(index);
    } else {
      updated.add(index);
    }
    state = state.copyWith(selectedIndices: updated);
  }

  /// Apply the selected sub-concepts to the knowledge graph.
  Future<void> applySplit() async {
    final suggestion = state.suggestion;
    final parentId = state.parentConceptId;
    if (suggestion == null || parentId == null) return;
    if (state.selectedIndices.isEmpty) return;

    state = state.copyWith(phase: SplitPhase.applying);

    final selectedEntries = [
      for (var i = 0; i < suggestion.entries.length; i++)
        if (state.selectedIndices.contains(i)) suggestion.entries[i],
    ];

    final children = <Concept>[];
    final childRelationships = <Relationship>[];
    final childQuizItems = <QuizItem>[];

    for (final entry in selectedEntries) {
      children.add(entry.concept);
      childQuizItems.addAll(entry.quizItems);

      // "is part of" relationship from child to parent
      childRelationships.add(
        Relationship(
          id: '${entry.concept.id}-part-of-$parentId',
          fromConceptId: entry.concept.id,
          toConceptId: parentId,
          label: 'is part of',
        ),
      );
    }

    final notifier = ref.read(knowledgeGraphProvider.notifier);
    await notifier.splitConcept(
      children: children,
      childRelationships: childRelationships,
      childQuizItems: childQuizItems,
    );

    state = const SplitState(); // back to idle
  }

  void reset() {
    state = const SplitState();
  }
}
