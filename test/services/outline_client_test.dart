import 'dart:convert';

import 'package:engram/src/services/outline_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('OutlineClient', () {
    test('listCollections returns collection data', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/collections.list');
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'col-1', 'name': 'Engineering'},
              {'id': 'col-2', 'name': 'Design'},
            ],
          }),
          200,
        );
      });

      final client = OutlineClient(
        apiUrl: 'https://wiki.example.com',
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final collections = await client.listCollections();

      expect(collections.length, 2);
      expect(collections[0]['name'], 'Engineering');
    });

    test('findCollection returns match case-insensitively', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'col-1', 'name': 'Engineering'},
            ],
          }),
          200,
        );
      });

      final client = OutlineClient(
        apiUrl: 'https://wiki.example.com',
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final result = await client.findCollection('engineering');
      expect(result, isNotNull);
      expect(result!['id'], 'col-1');
    });

    test('findCollection returns null when not found', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'data': <Map<String, dynamic>>[]}),
          200,
        );
      });

      final client = OutlineClient(
        apiUrl: 'https://wiki.example.com',
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final result = await client.findCollection('nonexistent');
      expect(result, isNull);
    });

    test('listDocuments handles pagination', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        if (callCount == 1) {
          expect(body['offset'], 0);
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'doc-1', 'title': 'Doc 1'},
                {'id': 'doc-2', 'title': 'Doc 2'},
              ],
              'pagination': {'total': 3},
            }),
            200,
          );
        } else {
          expect(body['offset'], 25);
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'doc-3', 'title': 'Doc 3'},
              ],
              'pagination': {'total': 3},
            }),
            200,
          );
        }
      });

      final client = OutlineClient(
        apiUrl: 'https://wiki.example.com',
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final docs = await client.listDocuments('col-1');

      expect(docs.length, 3);
      expect(callCount, 2);
    });

    test('getDocument returns document data', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/documents.info');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['id'], 'doc-1');

        return http.Response(
          jsonEncode({
            'data': {
              'id': 'doc-1',
              'title': 'Test Doc',
              'text': '# Hello World',
            },
          }),
          200,
        );
      });

      final client = OutlineClient(
        apiUrl: 'https://wiki.example.com',
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final doc = await client.getDocument('doc-1');
      expect(doc['text'], '# Hello World');
    });

    test('throws OutlineApiException on non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final client = OutlineClient(
        apiUrl: 'https://wiki.example.com',
        apiKey: 'bad-key',
        httpClient: mockClient,
      );

      expect(
        () => client.listCollections(),
        throwsA(isA<OutlineApiException>()),
      );
    });

    test('strips trailing slash from apiUrl', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          startsWith('https://wiki.example.com/api/'),
        );
        return http.Response(jsonEncode({'data': <dynamic>[]}), 200);
      });

      final client = OutlineClient(
        apiUrl: 'https://wiki.example.com/',
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      await client.listCollections();
    });
  });
}
