import 'dart:convert';

import 'package:engram/src/providers/document_diff_provider.dart';
import 'package:engram/src/providers/service_providers.dart';
import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/services/outline_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('DocumentDiffNotifier', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer createContainer({
      required http.Client httpClient,
    }) {
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          outlineClientProvider.overrideWithValue(
            OutlineClient(
              apiUrl: 'https://wiki.test.com',
              apiKey: 'test-key',
              httpClient: httpClient,
            ),
          ),
        ],
      );
    }

    test('initial state is idle', () {
      final mockClient = MockClient((_) async => http.Response('{}', 200));
      final container = createContainer(httpClient: mockClient);

      final state = container.read(documentDiffProvider);
      expect(state, isA<DocumentDiffIdle>());
    });

    test('fetchDiff transitions to loading then loaded', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/documents.info') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'doc-1',
                'title': 'Test Doc',
                'text': '# Updated\nNew paragraph.',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/documents.revisions') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'rev-3',
                  'text': '# Updated\nNew paragraph.',
                  'createdAt': '2026-02-19T10:00:00Z',
                },
                {
                  'id': 'rev-2',
                  'text': '# Updated',
                  'createdAt': '2026-02-18T12:00:00Z',
                },
                {
                  'id': 'rev-1',
                  'text': '# Original',
                  'createdAt': '2026-02-17T10:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(httpClient: mockClient);
      final notifier = container.read(documentDiffProvider.notifier);

      // ingestedAt is between rev-1 and rev-2, so rev-1 should be the old text
      await notifier.fetchDiff(
        documentId: 'doc-1',
        ingestedAt: '2026-02-18T00:00:00Z',
      );

      final state = container.read(documentDiffProvider);
      expect(state, isA<DocumentDiffLoaded>());

      final loaded = state as DocumentDiffLoaded;
      expect(loaded.oldText, '# Original');
      expect(loaded.newText, '# Updated\nNew paragraph.');
      expect(loaded.revisionDate, DateTime.utc(2026, 2, 17, 10));
    });

    test('picks closest revision at or before ingestedAt', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/documents.info') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'doc-1',
                'text': '# Latest',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/documents.revisions') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'rev-3',
                  'text': '# Latest',
                  'createdAt': '2026-02-19T10:00:00Z',
                },
                {
                  'id': 'rev-2',
                  'text': '# Middle',
                  'createdAt': '2026-02-15T10:00:00Z',
                },
                {
                  'id': 'rev-1',
                  'text': '# Oldest',
                  'createdAt': '2026-02-10T10:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(httpClient: mockClient);
      final notifier = container.read(documentDiffProvider.notifier);

      // ingestedAt is after rev-2 but before rev-3 — should pick rev-2
      await notifier.fetchDiff(
        documentId: 'doc-1',
        ingestedAt: '2026-02-16T00:00:00Z',
      );

      final loaded = container.read(documentDiffProvider) as DocumentDiffLoaded;
      expect(loaded.oldText, '# Middle');
      expect(loaded.revisionDate, DateTime.utc(2026, 2, 15, 10));
    });

    test('falls back to oldest revision when all are newer', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/documents.info') {
          return http.Response(
            jsonEncode({
              'data': {'id': 'doc-1', 'text': '# Current'},
            }),
            200,
          );
        }
        if (request.url.path == '/api/documents.revisions') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'rev-2',
                  'text': '# Current',
                  'createdAt': '2026-02-19T10:00:00Z',
                },
                {
                  'id': 'rev-1',
                  'text': '# Slightly Older',
                  'createdAt': '2026-02-18T10:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(httpClient: mockClient);
      final notifier = container.read(documentDiffProvider.notifier);

      await notifier.fetchDiff(
        documentId: 'doc-1',
        ingestedAt: '2026-02-01T00:00:00Z',
      );

      final loaded = container.read(documentDiffProvider) as DocumentDiffLoaded;
      expect(loaded.oldText, '# Slightly Older');
    });

    test('transitions to error on API failure', () async {
      final mockClient = MockClient((_) async {
        return http.Response('Server Error', 500);
      });

      final container = createContainer(httpClient: mockClient);
      final notifier = container.read(documentDiffProvider.notifier);

      await notifier.fetchDiff(
        documentId: 'doc-1',
        ingestedAt: '2026-02-18T00:00:00Z',
      );

      final state = container.read(documentDiffProvider);
      expect(state, isA<DocumentDiffError>());
      expect((state as DocumentDiffError).message, contains('failed'));
    });

    test('reset returns to idle', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/documents.info') {
          return http.Response(
            jsonEncode({
              'data': {'id': 'doc-1', 'text': '# Current'},
            }),
            200,
          );
        }
        if (request.url.path == '/api/documents.revisions') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'rev-1',
                  'text': '# Old',
                  'createdAt': '2026-02-17T10:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final container = createContainer(httpClient: mockClient);
      final notifier = container.read(documentDiffProvider.notifier);

      await notifier.fetchDiff(
        documentId: 'doc-1',
        ingestedAt: '2026-02-18T00:00:00Z',
      );
      expect(container.read(documentDiffProvider), isA<DocumentDiffLoaded>());

      notifier.reset();
      expect(container.read(documentDiffProvider), isA<DocumentDiffIdle>());
    });
  });
}
