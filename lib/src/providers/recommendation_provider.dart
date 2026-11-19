import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../engine/recommendation_evaluation.dart';
import '../models/knowledge_gap.dart';
import '../models/recommendation.dart';
import '../services/extraction_service.dart';
import '../services/outline_client.dart';
import 'clock_provider.dart';
import 'difficulty_evaluation_provider.dart';
import 'gap_analysis_provider.dart';
import 'knowledge_graph_provider.dart';
import 'service_providers.dart';

/// Phase of the recommendation pipeline.
enum RecommendationPhase { idle, analyzing, searching, evaluating, done, error }

/// Status of a single recommendation's ingestion.
enum RecommendationIngestStatus {
  idle,
  ingesting,
  evaluating,
  completed,
  error,
}

/// Result of ingesting a recommended document.
@immutable
class RecommendationIngestResult {
  const RecommendationIngestResult({
    this.status = RecommendationIngestStatus.idle,
    this.evaluation,
    this.errorMessage,
    this.ingestedConceptIds = const {},
  });

  final RecommendationIngestStatus status;
  final RecommendationEvaluationResult? evaluation;
  final String? errorMessage;

  /// IDs of concepts added during ingestion, used for glow animation.
  final Set<String> ingestedConceptIds;

  RecommendationIngestResult copyWith({
    RecommendationIngestStatus? status,
    RecommendationEvaluationResult? evaluation,
    String? errorMessage,
    Set<String>? ingestedConceptIds,
  }) {
    return RecommendationIngestResult(
      status: status ?? this.status,
      evaluation: evaluation ?? this.evaluation,
      errorMessage: errorMessage ?? this.errorMessage,
      ingestedConceptIds: ingestedConceptIds ?? this.ingestedConceptIds,
    );
  }
}

/// State for the recommendation pipeline.
@immutable
class RecommendationState {
  const RecommendationState({
    this.phase = RecommendationPhase.idle,
    this.gaps = const [],
    this.recommendations = const [],
    this.errorMessage = '',
    this.ingestResults = const {},
  });

  final RecommendationPhase phase;

  /// Gaps being analyzed (top N by severity).
  final List<KnowledgeGap> gaps;

  /// Final recommendations, sorted by score descending.
  final List<Recommendation> recommendations;

  /// Error message when phase is [RecommendationPhase.error].
  final String errorMessage;

  /// Per-document ingestion results, keyed by document ID.
  final Map<String, RecommendationIngestResult> ingestResults;

  RecommendationState copyWith({
    RecommendationPhase? phase,
    List<KnowledgeGap>? gaps,
    List<Recommendation>? recommendations,
    String? errorMessage,
    Map<String, RecommendationIngestResult>? ingestResults,
  }) {
    return RecommendationState(
      phase: phase ?? this.phase,
      gaps: gaps ?? this.gaps,
      recommendations: recommendations ?? this.recommendations,
      errorMessage: errorMessage ?? this.errorMessage,
      ingestResults: ingestResults ?? this.ingestResults,
    );
  }
}

final recommendationProvider =
    NotifierProvider<RecommendationNotifier, RecommendationState>(
      RecommendationNotifier.new,
    );

/// Notifier that drives the recommendation pipeline:
/// idle → analyzing → searching → evaluating → done/error.
class RecommendationNotifier extends Notifier<RecommendationState> {
  @override
  RecommendationState build() => const RecommendationState();

  /// Run the full recommendation pipeline for the top [maxGaps] knowledge gaps.
  Future<void> findRecommendations({int maxGaps = 3}) async {
    try {
      // 1. Analyze — read gaps from the gap analysis provider.
      state = state.copyWith(phase: RecommendationPhase.analyzing);
      final allGaps = ref.read(gapAnalysisProvider);
      final topGaps = allGaps.take(maxGaps).toList();

      if (topGaps.isEmpty) {
        state = state.copyWith(
          phase: RecommendationPhase.done,
          gaps: topGaps,
          recommendations: [],
        );
        return;
      }

      state = state.copyWith(gaps: topGaps);

      // 2. Search + evaluate — call RecommendationService for each gap.
      state = state.copyWith(phase: RecommendationPhase.searching);

      final service = ref.read(recommendationServiceProvider);
      final graph = ref.read(knowledgeGraphProvider).valueOrNull;

      final existingConceptNames =
          graph?.concepts.map((c) => c.name).toList() ?? [];
      final ingestedDocIds =
          graph?.documentMetadata.map((d) => d.documentId).toSet() ?? {};

      state = state.copyWith(phase: RecommendationPhase.evaluating);

      // Parallelize gap recommendations — each gap searches + evaluates
      // independently, then we deduplicate across results.
      final results = await Future.wait([
        for (final gap in topGaps)
          service.recommend(
            gap: gap,
            existingConceptNames: existingConceptNames,
            ingestedDocumentIds: ingestedDocIds,
          ),
      ]);

      final allRecommendations = <Recommendation>[];
      final seenDocIds = <String>{};

      for (final recs in results) {
        // Deduplicate across gaps (same doc might fill multiple).
        for (final rec in recs) {
          if (seenDocIds.add(rec.documentId)) {
            allRecommendations.add(rec);
          }
        }
      }

      // Sort by score descending.
      allRecommendations.sort((a, b) => b.score.compareTo(a.score));

      state = state.copyWith(
        phase: RecommendationPhase.done,
        recommendations: allRecommendations,
      );
    } catch (e) {
      state = state.copyWith(
        phase: RecommendationPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Ingest a recommended document and evaluate prediction accuracy.
  ///
  /// Fetches the document from Outline, extracts knowledge via Claude,
  /// merges into the graph, then compares predicted edges vs actual.
  Future<void> ingestRecommendation(Recommendation recommendation) async {
    final docId = recommendation.documentId;

    // Guard against double-tap: skip if already in progress.
    final existing = state.ingestResults[docId];
    if (existing != null &&
        existing.status != RecommendationIngestStatus.idle &&
        existing.status != RecommendationIngestStatus.error) {
      return;
    }

    void updateIngest(RecommendationIngestResult result) {
      state = state.copyWith(
        ingestResults: {...state.ingestResults, docId: result},
      );
    }

    try {
      // 1. Capture graph before ingestion.
      final graphBefore = await ref.read(knowledgeGraphProvider.future);

      // 2. Set status → ingesting.
      updateIngest(
        const RecommendationIngestResult(
          status: RecommendationIngestStatus.ingesting,
        ),
      );

      // 3. Fetch full document from Outline.
      final client = ref.read(outlineClientProvider);
      final fullDoc = await client.getDocument(docId);
      final content = fullDoc['text'] as String? ?? '';
      final title = fullDoc['title'] as String? ?? recommendation.documentTitle;

      // 4. Extract knowledge via Claude.
      final extractionService = ref.read(extractionServiceProvider);
      final existingIds = graphBefore.concepts.map((c) => c.id).toList();
      final predictionAccuracy = ref.read(difficultyEvaluationProvider);

      final extraction = await extractionService.extract(
        documentTitle: title,
        documentContent: content,
        existingConceptIds: existingIds,
        predictionAccuracy: predictionAccuracy,
      );

      // Capture new concept IDs for glow animation.
      final newConceptIds = extraction.concepts.map((c) => c.id).toSet();

      // 5. Merge into graph via non-staggered ingest.
      await ref
          .read(knowledgeGraphProvider.notifier)
          .ingestExtraction(
            extraction,
            documentId: docId,
            documentTitle: title,
            updatedAt: ref.read(clockProvider)().toIso8601String(),
            collectionId: recommendation.collectionId,
            collectionName: recommendation.collectionName,
            documentText: content,
          );

      // 6. Set status → evaluating.
      updateIngest(
        const RecommendationIngestResult(
          status: RecommendationIngestStatus.evaluating,
        ),
      );

      // 7. Capture graph after and evaluate.
      final graphAfter = await ref.read(knowledgeGraphProvider.future);
      final evaluation = evaluateRecommendation(
        recommendation: recommendation,
        graphBefore: graphBefore,
        graphAfter: graphAfter,
      );

      // 8. Set status → completed with evaluation and concept IDs.
      updateIngest(
        RecommendationIngestResult(
          status: RecommendationIngestStatus.completed,
          evaluation: evaluation,
          ingestedConceptIds: newConceptIds,
        ),
      );
    } on OutlineApiException catch (e) {
      updateIngest(
        RecommendationIngestResult(
          status: RecommendationIngestStatus.error,
          errorMessage: 'Failed to fetch document: ${e.message}',
        ),
      );
    } on ExtractionException catch (e) {
      updateIngest(
        RecommendationIngestResult(
          status: RecommendationIngestStatus.error,
          errorMessage: 'Extraction failed: ${e.message}',
        ),
      );
    } catch (e) {
      updateIngest(
        RecommendationIngestResult(
          status: RecommendationIngestStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Reset to idle state.
  void reset() {
    state = const RecommendationState();
  }
}
