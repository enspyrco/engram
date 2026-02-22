import 'dart:convert';
import 'dart:io';

import 'package:engram/src/engine/graph_analyzer.dart';
import 'package:engram/src/engine/review_rating.dart';
import 'package:engram/src/engine/scheduler.dart';
import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/document_metadata.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/quiz_item.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/models/sync_status.dart';
import 'package:engram/src/providers/dashboard_stats_provider.dart';
import 'package:engram/src/providers/graph_store_provider.dart';
import 'package:engram/src/providers/knowledge_graph_provider.dart';
import 'package:engram/src/providers/quiz_session_provider.dart';
import 'package:engram/src/providers/service_providers.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/providers/sync_provider.dart';
import 'package:engram/src/models/quiz_session_state.dart';
import 'package:engram/src/services/extraction_service.dart';
import 'package:engram/src/services/outline_client.dart';
import 'package:engram/src/storage/config.dart';
import 'package:engram/src/storage/local_graph_repository.dart';
import 'package:engram/src/storage/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class MockExtractionService extends Mock implements ExtractionService {}

/// A fixed "now" for all test graphs. Items with nextReview in the past are due.
final _testNow = DateTime.utc(2026, 1, 15);
final _pastReview = _testNow.subtract(const Duration(days: 1));
final _ingestedAt = _testNow.subtract(const Duration(days: 14));
final _docUpdatedAt =
    _testNow.subtract(const Duration(days: 15)).toIso8601String();

/// Builds a graph modeling: Docker (foundational) → Kubernetes (depends on Docker)
/// → Helm (depends on Kubernetes). This creates a 3-tier dependency chain.
KnowledgeGraph buildDependencyGraph({
  int dockerReps = 0,
  int kubernetesReps = 0,
}) {
  return KnowledgeGraph(
    concepts: [
      Concept(
        id: 'docker',
        name: 'Docker',
        description: 'Container runtime',
        sourceDocumentId: 'doc1',
      ),
      Concept(
        id: 'kubernetes',
        name: 'Kubernetes',
        description: 'Container orchestration',
        sourceDocumentId: 'doc1',
      ),
      Concept(
        id: 'helm',
        name: 'Helm',
        description: 'Kubernetes package manager',
        sourceDocumentId: 'doc1',
      ),
    ],
    relationships: [
      const Relationship(
        id: 'r1',
        fromConceptId: 'kubernetes',
        toConceptId: 'docker',
        label: 'depends on',
      ),
      const Relationship(
        id: 'r2',
        fromConceptId: 'helm',
        toConceptId: 'kubernetes',
        label: 'requires',
      ),
    ],
    quizItems: [
      QuizItem(
        id: 'q-docker',
        conceptId: 'docker',
        question: 'What is Docker?',
        answer: 'A container runtime.',
        easeFactor: 2.5,
        interval: 0,
        repetitions: dockerReps,
        nextReview: _pastReview,
        lastReview: null,
      ),
      QuizItem(
        id: 'q-kubernetes',
        conceptId: 'kubernetes',
        question: 'What is Kubernetes?',
        answer: 'Container orchestration platform.',
        easeFactor: 2.5,
        interval: 0,
        repetitions: kubernetesReps,
        nextReview: _pastReview,
        lastReview: null,
      ),
      QuizItem(
        id: 'q-helm',
        conceptId: 'helm',
        question: 'What is Helm?',
        answer: 'Kubernetes package manager.',
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        nextReview: _pastReview,
        lastReview: null,
      ),
    ],
    documentMetadata: [
      DocumentMetadata(
        documentId: 'doc1',
        title: 'DevOps Guide',
        updatedAt: _docUpdatedAt,
        ingestedAt: _ingestedAt,
      ),
    ],
  );
}

void main() {
  group('Living system integration', () {
    late Directory tempDir;
    late LocalGraphRepository store;
    late SharedPreferences prefs;
    late SettingsRepository settingsRepo;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('engram_integration_');
      store = LocalGraphRepository(dataDir: tempDir.path);
      SharedPreferences.setMockInitialValues({
        'outline_api_url': 'https://wiki.test.com',
        'outline_api_key': 'test-key',
        'anthropic_api_key': 'sk-ant-test',
        'ingested_collection_ids': ['col1'],
      });
      prefs = await SharedPreferences.getInstance();
      settingsRepo = SettingsRepository(prefs);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    ProviderContainer createContainer(
      KnowledgeGraph graph, {
      http.Client? httpClient,
      ExtractionService? extraction,
    }) {
      final json = const JsonEncoder.withIndent('  ').convert(graph.toJson());
      File('${tempDir.path}/knowledge_graph.json').writeAsStringSync(json);

      return ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _FakeSettingsNotifier(tempDir.path),
          ),
          graphRepositoryProvider.overrideWithValue(store),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          if (httpClient != null)
            outlineClientProvider.overrideWithValue(
              OutlineClient(
                apiUrl: 'https://wiki.test.com',
                apiKey: 'test-key',
                httpClient: httpClient,
              ),
            ),
          if (extraction != null)
            extractionServiceProvider.overrideWithValue(extraction),
        ],
      );
    }

    test(
      'dependency chain: only foundational concepts are schedulable initially',
      () async {
        final graph = buildDependencyGraph();
        final container = createContainer(graph);
        await container.read(knowledgeGraphProvider.future);

        final stats = container.read(dashboardStatsProvider);

        // Docker is foundational (no prerequisites)
        expect(stats.foundationalCount, 1);
        // Docker is unlocked, plus it itself has no prereqs
        // Kubernetes depends on Docker (unmastered) → locked
        // Helm depends on Kubernetes (unmastered) → locked
        expect(stats.lockedCount, 2);

        // Only Docker's quiz item should be due (Kubernetes & Helm are locked)
        final loadedGraph = await container.read(knowledgeGraphProvider.future);
        final due = scheduleDueItems(loadedGraph);
        expect(due, hasLength(1));
        expect(due.first.conceptId, 'docker');
      },
    );

    test('mastering a concept unlocks its dependents', () async {
      // Docker already mastered (reps=1), so Kubernetes should unlock
      final graph = buildDependencyGraph(dockerReps: 1);
      final container = createContainer(graph);
      await container.read(knowledgeGraphProvider.future);

      final stats = container.read(dashboardStatsProvider);

      // Docker mastered → Kubernetes unlocked, Helm still locked
      expect(stats.lockedCount, 1); // only Helm
      expect(stats.unlockedCount, 2); // Docker + Kubernetes

      final loadedGraph = await container.read(knowledgeGraphProvider.future);
      final due = scheduleDueItems(loadedGraph);
      // Docker (reps=1 but nextReview is in the past) + Kubernetes should be due
      expect(
        due.map((q) => q.conceptId),
        containsAll(['docker', 'kubernetes']),
      );
      expect(due.any((q) => q.conceptId == 'helm'), isFalse);
    });

    test('quiz session updates SM-2 state and persists to graph', () async {
      final graph = buildDependencyGraph();
      final container = createContainer(graph);
      await container.read(knowledgeGraphProvider.future);

      // Start a quiz session — only Docker should appear
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();

      var session = container.read(quizSessionProvider);
      expect(session.phase, QuizPhase.question);
      expect(session.items, hasLength(1));
      expect(session.items.first.conceptId, 'docker');

      // Complete the review: reveal → rate 5 (perfect recall)
      notifier.revealAnswer();
      await notifier.rateItem(const Sm2Rating(5));

      session = container.read(quizSessionProvider);
      expect(session.phase, QuizPhase.summary);
      expect(session.correctCount, 1);

      // Verify the SM-2 update persisted
      final updatedGraph = await container.read(knowledgeGraphProvider.future);
      final dockerItem = updatedGraph.quizItems.firstWhere(
        (q) => q.conceptId == 'docker',
      );
      expect(dockerItem.repetitions, 1);
      expect(dockerItem.interval, greaterThan(0));
    });

    test('dashboard stats recompute after quiz completes', () async {
      final graph = buildDependencyGraph();
      final container = createContainer(graph);
      await container.read(knowledgeGraphProvider.future);

      final statsBefore = container.read(dashboardStatsProvider);
      expect(statsBefore.newCount, 3); // all items have reps=0

      // Review Docker with perfect score
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();
      notifier.revealAnswer();
      await notifier.rateItem(const Sm2Rating(5));

      final statsAfter = container.read(dashboardStatsProvider);
      expect(statsAfter.newCount, 2); // Docker moved out of "new"
      expect(statsAfter.learningCount, 1); // Docker is now "learning"
    });

    test('"unlocking next" identifies concepts close to unlocking', () async {
      // Docker mastered → Kubernetes unlocked but not mastered
      // Helm depends on Kubernetes (1 unmastered prereq) → "close to unlocking"
      final graph = buildDependencyGraph(dockerReps: 1);

      final analyzer = GraphAnalyzer(graph);

      // Helm is locked (Kubernetes not mastered)
      expect(analyzer.lockedConcepts, ['helm']);

      // Check Helm's prerequisites
      final helmPrereqs = analyzer.prerequisitesOf('helm');
      expect(helmPrereqs, {'kubernetes'});

      // Count unmastered prereqs for Helm
      final unmasteredPrereqs =
          helmPrereqs.where((p) => !analyzer.isConceptMastered(p)).toList();
      expect(unmasteredPrereqs, hasLength(1)); // Only Kubernetes
      // This means Helm would appear in "Almost unlocking" on the session summary
    });

    test('full flow: quiz mastery cascades through dependency chain', () async {
      final graph = buildDependencyGraph();
      final container = createContainer(graph);
      await container.read(knowledgeGraphProvider.future);

      // Phase 1: Only Docker is due
      var loadedGraph = await container.read(knowledgeGraphProvider.future);
      var due = scheduleDueItems(loadedGraph);
      expect(due, hasLength(1));
      expect(due.first.conceptId, 'docker');

      // Master Docker
      final notifier = container.read(quizSessionProvider.notifier);
      notifier.startSession();
      notifier.revealAnswer();
      await notifier.rateItem(const Sm2Rating(5));
      notifier.reset();

      // Phase 2: Now Kubernetes should also be available
      loadedGraph = await container.read(knowledgeGraphProvider.future);
      due = scheduleDueItems(loadedGraph);
      final dueConceptIds = due.map((q) => q.conceptId).toSet();
      expect(dueConceptIds.contains('kubernetes'), isTrue);
      expect(dueConceptIds.contains('helm'), isFalse); // Still locked

      // Master Kubernetes
      notifier.startSession();
      // Session should include Kubernetes (and Docker again since nextReview is past)
      final session = container.read(quizSessionProvider);
      expect(session.items.any((q) => q.conceptId == 'kubernetes'), isTrue);

      // Rate all items in this session
      for (var i = 0; i < session.items.length; i++) {
        notifier.revealAnswer();
        await notifier.rateItem(const Sm2Rating(5));
      }
      notifier.reset();

      // Phase 3: Now Helm should be unlocked
      loadedGraph = await container.read(knowledgeGraphProvider.future);
      due = scheduleDueItems(loadedGraph);
      expect(due.any((q) => q.conceptId == 'helm'), isTrue);
    });

    test('sync detection finds stale documents in graph', () async {
      final graph = buildDependencyGraph();
      final mockExtraction = MockExtractionService();

      // Outline returns a newer updatedAt → stale
      final client = MockClient((request) async {
        if (request.url.path == '/api/collections.list') {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'col1', 'name': 'DevOps'},
              ],
              'pagination': {'total': 1},
            }),
            200,
          );
        }
        if (request.url.path == '/api/documents.list') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'doc1',
                  'title': 'DevOps Guide',
                  'updatedAt': _testNow.toIso8601String(), // newer than graph
                },
              ],
              'pagination': {'total': 1},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(
        graph,
        httpClient: client,
        extraction: mockExtraction,
      );
      await container.read(knowledgeGraphProvider.future);
      await container.read(syncProvider.notifier).checkForUpdates();

      final syncStatus = container.read(syncProvider);
      expect(syncStatus.phase, SyncPhase.updatesAvailable);
      expect(syncStatus.staleDocumentCount, 1);
    });
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._dataDir);
  final String _dataDir;

  @override
  EngramConfig build() => EngramConfig(
    dataDir: _dataDir,
    outlineApiUrl: 'https://wiki.test.com',
    outlineApiKey: 'test-key',
    anthropicApiKey: 'sk-ant-test',
  );
}
