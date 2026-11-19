import 'dart:convert';

import 'package:engram/src/services/elevenlabs_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('ElevenLabsClient', () {
    test('synthesizeWithTimestamps returns audio and alignment data', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.elevenlabs.io');
        expect(request.url.path, contains('/v1/text-to-speech/'));
        expect(request.url.path, endsWith('/with-timestamps'));
        expect(request.headers['xi-api-key'], 'test-key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['text'], 'Hello world');

        return http.Response(
          jsonEncode({
            'audio_base64': base64Encode([0x00, 0x01, 0x02, 0x03]),
            'alignment': {
              'characters': ['H', 'e', 'l', 'l', 'o'],
              'character_start_times_seconds': [0.0, 0.05, 0.1, 0.15, 0.2],
              'character_end_times_seconds': [0.05, 0.1, 0.15, 0.2, 0.25],
            },
          }),
          200,
        );
      });

      final client = ElevenLabsClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final response = await client.synthesizeWithTimestamps('Hello world');

      expect(response.audioBytes, hasLength(4));
      expect(response.characters, ['H', 'e', 'l', 'l', 'o']);
      expect(response.characterStartTimes, hasLength(5));
      expect(response.characterEndTimes, hasLength(5));
      expect(response.characterStartTimes[0], 0.0);
      expect(response.characterEndTimes[4], 0.25);
    });

    test('uses specified voiceId in URL', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/custom-voice-id/'));
        return http.Response(
          jsonEncode({
            'audio_base64': base64Encode([0x00]),
            'alignment': {
              'characters': ['H'],
              'character_start_times_seconds': [0.0],
              'character_end_times_seconds': [0.1],
            },
          }),
          200,
        );
      });

      final client = ElevenLabsClient(
        apiKey: 'test-key',
        voiceId: 'custom-voice-id',
        httpClient: mockClient,
      );

      await client.synthesizeWithTimestamps('Hi');
    });

    test('throws ElevenLabsException on non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'status': 'quota_exceeded',
              'message': 'You have exceeded your character quota.',
            },
          }),
          401,
        );
      });

      final client = ElevenLabsClient(
        apiKey: 'bad-key',
        httpClient: mockClient,
      );

      expect(
        () => client.synthesizeWithTimestamps('Hello'),
        throwsA(isA<ElevenLabsException>()),
      );
    });

    test('throws ElevenLabsException on malformed JSON response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            // Missing 'alignment' key
            'audio_base64': base64Encode([0x00]),
          }),
          200,
        );
      });

      final client = ElevenLabsClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.synthesizeWithTimestamps('Hello'),
        throwsA(isA<ElevenLabsException>()),
      );
    });

    test('passes model_id and output_format in request body', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model_id'], isNotEmpty);
        expect(body['output_format'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'audio_base64': base64Encode([0x00]),
            'alignment': {
              'characters': ['X'],
              'character_start_times_seconds': [0.0],
              'character_end_times_seconds': [0.1],
            },
          }),
          200,
        );
      });

      final client = ElevenLabsClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      await client.synthesizeWithTimestamps('X');
    });
  });
}
