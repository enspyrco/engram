import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';

import 'elevenlabs_client.dart';

final _random = Random();

/// Retries [fn] with exponential backoff + jitter on transient errors.
///
/// Catches only errors that are likely to succeed on retry:
/// - [SocketException] / [TimeoutException] — network transients
/// - [AnthropicClientException] with status 429 (rate limit) or 529 (overloaded)
/// - [ElevenLabsException] with "429" or "529" in the message
///
/// Non-transient errors (400, 401, 403, etc.) are rethrown immediately.
///
/// Uses `baseDelay * 2^attempt` plus random jitter (0–50% of the delay) to
/// avoid thundering herd on rate limits during bulk operations.
Future<T> retryWithBackoff<T>(
  Future<T> Function() fn, {
  int maxRetries = 2,
  Duration baseDelay = const Duration(seconds: 1),
}) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await fn();
    } catch (e) {
      if (attempt >= maxRetries || !_isTransient(e)) rethrow;

      final delay = baseDelay * (1 << attempt);
      final jitter = Duration(
        milliseconds: _random.nextInt(delay.inMilliseconds ~/ 2 + 1),
      );
      await Future<void>.delayed(delay + jitter);
    }
  }
}

/// Returns true if the error is transient and worth retrying.
bool _isTransient(Object e) {
  // Network errors
  if (e is SocketException || e is TimeoutException) return true;

  // Anthropic API rate limit (429) or overload (529)
  if (e is AnthropicClientException) {
    final code = e.code;
    return code == 429 || code == 529;
  }

  // ElevenLabs errors — check the message since the exception doesn't
  // expose status codes directly
  if (e is ElevenLabsException) {
    return e.message.contains('429') || e.message.contains('529');
  }

  return false;
}
