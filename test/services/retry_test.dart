import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
// HttpMethod is not publicly exported by anthropic_sdk_dart but is required
// to construct AnthropicClientException in tests. Track upstream issue.
import 'package:anthropic_sdk_dart/src/generated/client.dart' show HttpMethod;
import 'package:engram/src/services/elevenlabs_client.dart';
import 'package:engram/src/services/retry.dart';
import 'package:test/test.dart';

void main() {
  group('retryWithBackoff', () {
    test('returns result on first success', () async {
      final result = await retryWithBackoff(
        () async => 42,
        baseDelay: Duration.zero,
      );
      expect(result, 42);
    });

    test('retries on SocketException and succeeds', () async {
      var attempts = 0;
      final result = await retryWithBackoff(() async {
        attempts++;
        if (attempts < 2) throw const SocketException('connection refused');
        return 'success';
      }, baseDelay: Duration.zero);

      expect(result, 'success');
      expect(attempts, 2);
    });

    test('retries on Anthropic 429 rate limit', () async {
      var attempts = 0;
      final result = await retryWithBackoff(() async {
        attempts++;
        if (attempts < 2) {
          throw AnthropicClientException(
            message: 'rate limited',
            uri: Uri.parse('https://api.anthropic.com/v1/messages'),
            method: HttpMethod.post,
            code: 429,
          );
        }
        return 'ok';
      }, baseDelay: Duration.zero);

      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('retries on Anthropic 529 overload', () async {
      var attempts = 0;
      final result = await retryWithBackoff(() async {
        attempts++;
        if (attempts < 2) {
          throw AnthropicClientException(
            message: 'overloaded',
            uri: Uri.parse('https://api.anthropic.com/v1/messages'),
            method: HttpMethod.post,
            code: 529,
          );
        }
        return 'ok';
      }, baseDelay: Duration.zero);

      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('retries on ElevenLabs 429 error', () async {
      var attempts = 0;
      final result = await retryWithBackoff(() async {
        attempts++;
        if (attempts < 2) {
          throw ElevenLabsException(
            'TTS request failed: 429 Too Many Requests',
          );
        }
        return 'ok';
      }, baseDelay: Duration.zero);

      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('gives up after maxRetries', () async {
      var attempts = 0;
      await expectLater(
        retryWithBackoff(
          () async {
            attempts++;
            throw const SocketException('always fails');
          },
          maxRetries: 2,
          baseDelay: Duration.zero,
        ),
        throwsA(isA<SocketException>()),
      );

      expect(attempts, 3); // 1 initial + 2 retries
    });

    test('does not retry on non-transient Anthropic error (400)', () async {
      var attempts = 0;
      await expectLater(
        retryWithBackoff(() async {
          attempts++;
          throw AnthropicClientException(
            message: 'bad request',
            uri: Uri.parse('https://api.anthropic.com/v1/messages'),
            method: HttpMethod.post,
            code: 400,
          );
        }, baseDelay: Duration.zero),
        throwsA(isA<AnthropicClientException>()),
      );

      expect(attempts, 1); // No retries
    });

    test('does not retry on non-transient errors', () async {
      var attempts = 0;
      await expectLater(
        retryWithBackoff(() async {
          attempts++;
          throw StateError('not transient');
        }, baseDelay: Duration.zero),
        throwsA(isA<StateError>()),
      );

      expect(attempts, 1); // No retries
    });
  });
}
