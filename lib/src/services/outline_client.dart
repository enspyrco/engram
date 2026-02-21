import 'dart:convert';

import 'package:http/http.dart' as http;

class OutlineClient {
  OutlineClient({
    required String apiUrl,
    required String apiKey,
    http.Client? httpClient,
  }) : _apiUrl =
           apiUrl.endsWith('/')
               ? apiUrl.substring(0, apiUrl.length - 1)
               : apiUrl,
       _apiKey = apiKey,
       _httpClient = httpClient ?? http.Client();

  final String _apiUrl;
  final String _apiKey;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> _post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$_apiUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: body != null ? jsonEncode(body) : '{}',
    );

    if (response.statusCode != 200) {
      throw OutlineApiException(
        'POST $path failed: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// List all collections.
  Future<List<Map<String, dynamic>>> listCollections() async {
    final result = await _post('/api/collections.list');
    final data = result['data'] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Find a collection by name (case-insensitive).
  Future<Map<String, dynamic>?> findCollection(String name) async {
    final collections = await listCollections();
    final lowerName = name.toLowerCase();
    for (final collection in collections) {
      if ((collection['name'] as String).toLowerCase() == lowerName) {
        return collection;
      }
    }
    return null;
  }

  /// List all documents in a collection, handling pagination.
  Future<List<Map<String, dynamic>>> listDocuments(String collectionId) async {
    final allDocs = <Map<String, dynamic>>[];
    var offset = 0;
    const limit = 25;

    while (true) {
      final result = await _post('/api/documents.list', {
        'collectionId': collectionId,
        'offset': offset,
        'limit': limit,
      });

      final data = result['data'] as List<dynamic>;
      if (data.isEmpty) break;

      allDocs.addAll(data.cast<Map<String, dynamic>>());

      // Check pagination
      final pagination = result['pagination'] as Map<String, dynamic>?;
      if (pagination == null) break;
      final total = pagination['total'] as int? ?? data.length;
      if (allDocs.length >= total) break;

      offset += limit;
    }

    return allDocs;
  }

  /// Get a single document by ID.
  Future<Map<String, dynamic>> getDocument(String documentId) async {
    final result = await _post('/api/documents.info', {'id': documentId});
    return result['data'] as Map<String, dynamic>;
  }

  void close() => _httpClient.close();
}

class OutlineApiException implements Exception {
  OutlineApiException(this.message);

  final String message;

  @override
  String toString() => 'OutlineApiException: $message';
}
