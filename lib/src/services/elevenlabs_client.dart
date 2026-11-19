import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'retry.dart';

/// Default ElevenLabs voice: "Rachel" — clear, neutral, educational tone.
const _defaultVoiceId = '21m00Tcm4TlvDq8ikWAM';

/// Default model: multilingual v2, good balance of quality and latency.
const _defaultModelId = 'eleven_multilingual_v2';

/// Response from the ElevenLabs TTS with-timestamps endpoint.
@immutable
class TtsResponse {
  const TtsResponse({
    required this.audioBytes,
    required this.characters,
    required this.characterStartTimes,
    required this.characterEndTimes,
  });

  /// Raw audio bytes (MP3).
  final Uint8List audioBytes;

  /// Each character in the synthesized text.
  final List<String> characters;

  /// Start time in seconds for each character.
  final List<double> characterStartTimes;

  /// End time in seconds for each character.
  final List<double> characterEndTimes;
}

/// HTTP client for the ElevenLabs Text-to-Speech API.
///
/// Follows the same pattern as [OutlineClient]: constructor-injected
/// dependencies, typed exceptions, and a single public method.
class ElevenLabsClient {
  ElevenLabsClient({
    required String apiKey,
    String voiceId = _defaultVoiceId,
    http.Client? httpClient,
  }) : _apiKey = apiKey,
       _voiceId = voiceId,
       _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final String _voiceId;
  final http.Client _httpClient;

  /// Synthesize [text] and return audio bytes with character-level timestamps.
  ///
  /// Uses the `/v1/text-to-speech/{voiceId}/with-timestamps` endpoint which
  /// returns both the audio and per-character alignment data in a single call.
  Future<TtsResponse> synthesizeWithTimestamps(String text) async {
    final uri = Uri.parse(
      'https://api.elevenlabs.io/v1/text-to-speech/$_voiceId/with-timestamps',
    );

    return retryWithBackoff(() async {
      final response = await _httpClient.post(
        uri,
        headers: {'xi-api-key': _apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'model_id': _defaultModelId,
          'output_format': 'mp3_44100_128',
        }),
      );

      if (response.statusCode != 200) {
        throw ElevenLabsException(
          'TTS request failed: ${response.statusCode} ${response.body}',
        );
      }

      return _parseResponse(response.body);
    });
  }

  TtsResponse _parseResponse(String responseBody) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    final audioBase64 = json['audio_base64'] as String?;
    final alignment = json['alignment'] as Map<String, dynamic>?;

    if (audioBase64 == null || alignment == null) {
      throw ElevenLabsException(
        'Malformed TTS response: missing audio_base64 or alignment',
      );
    }

    final characters =
        (alignment['characters'] as List<dynamic>)
            .map((e) => e as String)
            .toList();
    final startTimes =
        (alignment['character_start_times_seconds'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();
    final endTimes =
        (alignment['character_end_times_seconds'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();

    return TtsResponse(
      audioBytes: base64Decode(audioBase64),
      characters: characters,
      characterStartTimes: startTimes,
      characterEndTimes: endTimes,
    );
  }

  void close() => _httpClient.close();
}

class ElevenLabsException implements Exception {
  ElevenLabsException(this.message);

  final String message;

  @override
  String toString() => 'ElevenLabsException: $message';
}
