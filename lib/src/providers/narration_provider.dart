// ignore_for_file: experimental_member_use
// just_audio's StreamAudioSource API is marked @experimental but is the only
// way to play in-memory audio without writing temp files. The alternative
// (temp file I/O for a ~1.4 MB clip) is worse for both performance and
// cleanup. This suppression is scoped to this file only.
import 'dart:async';
import 'dart:typed_data';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../engine/concept_marker_parser.dart';
import '../engine/timestamp_mapper.dart';
import '../models/narration_session.dart';
import '../models/timestamped_concept.dart';
import '../services/narration_service.dart';
import 'service_providers.dart';

/// Minimum position change (in seconds) to trigger a state update when the
/// active concept set hasn't changed. Prevents excessive rebuilds from
/// high-frequency position ticks while keeping the progress bar smooth.
const _kPositionUpdateThreshold = 0.1;

final narrationProvider = NotifierProvider<NarrationNotifier, NarrationSession>(
  NarrationNotifier.new,
);

/// Computes the set of concept IDs active at the given playback [position].
///
/// Extracted as a top-level pure function so it can be tested independently
/// of audio player and Riverpod machinery.
Set<String> computeActiveConcepts(
  List<TimestampedConcept> concepts,
  double position,
) {
  final active = <String>{};
  for (final tc in concepts) {
    if (tc.containsPosition(position)) {
      active.add(tc.conceptId);
    }
  }
  return active;
}

/// Notifier that drives the narration pipeline:
/// idle → generatingScript → synthesizingAudio → ready → playing ↔ paused → completed | error.
///
/// Follows the same state-machine pattern as [RecommendationNotifier].
///
/// This notifier lives in the global Riverpod container, so audio playback
/// continues when the user navigates away from the narration screen. This is
/// intentional — narration is background audio by design, similar to a podcast
/// player.
class NarrationNotifier extends Notifier<NarrationSession> {
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  /// Cached `.toList()` of timestamped concepts, set once in [_preparePlayer]
  /// and reused on every position tick to avoid per-tick allocation.
  List<TimestampedConcept> _timestampedConceptsList = const [];

  @override
  NarrationSession build() => const NarrationSession();

  /// Run the full narration pipeline for the given concepts.
  Future<void> generateNarration({
    required List<ConceptSummary> concepts,
    required List<RelationshipSummary> relationships,
  }) async {
    try {
      // Phase 1: Generate script via Claude.
      state = state.copyWith(phase: NarrationPhase.generatingScript);

      final narrationService = ref.read(narrationServiceProvider);
      final annotatedScript = await narrationService.generateNarrationScript(
        concepts: concepts,
        relationships: relationships,
      );

      // Parse markers from the annotated script.
      final parseResult = parseConceptMarkers(annotatedScript);

      state = state.copyWith(scriptText: parseResult.strippedText);

      // Phase 2: Synthesize audio via ElevenLabs.
      state = state.copyWith(phase: NarrationPhase.synthesizingAudio);

      final ttsClient = ref.read(elevenLabsClientProvider);
      final ttsResponse = await ttsClient.synthesizeWithTimestamps(
        parseResult.strippedText,
      );

      // Map character offsets to time ranges.
      final timestamped = mapMarkersToTimestamps(
        markers: parseResult.markers,
        characterStartTimes: ttsResponse.characterStartTimes,
        characterEndTimes: ttsResponse.characterEndTimes,
      );

      // Compute duration from the last character end time.
      final duration =
          ttsResponse.characterEndTimes.isNotEmpty
              ? ttsResponse.characterEndTimes.last
              : 0.0;

      // Prepare audio player.
      await _preparePlayer(ttsResponse.audioBytes);

      state = state.copyWith(
        phase: NarrationPhase.ready,
        timestampedConcepts: IList(timestamped),
        audioBytes: ttsResponse.audioBytes,
        durationSeconds: duration,
      );
    } catch (e) {
      state = state.copyWith(
        phase: NarrationPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Start or resume audio playback.
  void play() {
    if (_player == null) return;
    _player!.play();
    state = state.copyWith(phase: NarrationPhase.playing);
  }

  /// Pause audio playback.
  void pause() {
    if (_player == null) return;
    _player!.pause();
    state = state.copyWith(phase: NarrationPhase.paused);
  }

  /// Seek to a specific [position] in the audio.
  void seek(Duration position) {
    _player?.seek(position);
  }

  /// Reset to idle state and dispose the audio player.
  void reset() {
    _disposePlayer();
    state = const NarrationSession();
  }

  /// Prepare the audio player with in-memory bytes.
  Future<void> _preparePlayer(Uint8List audioBytes) async {
    _disposePlayer();
    _player = AudioPlayer();

    // Cache the concept list so _onPositionUpdate doesn't allocate per tick.
    _timestampedConceptsList = state.timestampedConcepts.toList();

    // Load from in-memory bytes via StreamAudioSource.
    await _player!.setAudioSource(_BytesAudioSource(audioBytes));

    // Listen to position changes.
    _positionSub = _player!.positionStream.listen(_onPositionUpdate);

    // Listen to player state for completion detection.
    _playerStateSub = _player!.playerStateStream.listen(_onPlayerStateChange);
  }

  void _onPositionUpdate(Duration position) {
    final seconds = position.inMilliseconds / 1000.0;

    // Compute which concepts are active at this position.
    final active = computeActiveConcepts(_timestampedConceptsList, seconds);

    // Only update state when the active set or position changes meaningfully.
    final newActiveConcepts = ISet(active);
    if (newActiveConcepts != state.activeConcepts) {
      state = state.copyWith(
        positionSeconds: seconds,
        activeConcepts: newActiveConcepts,
      );
    } else if ((seconds - state.positionSeconds).abs() >
        _kPositionUpdateThreshold) {
      // Update position for progress bar even if concepts haven't changed.
      state = state.copyWith(positionSeconds: seconds);
    }
  }

  void _onPlayerStateChange(PlayerState playerState) {
    if (playerState.processingState == ProcessingState.completed) {
      state = state.copyWith(
        phase: NarrationPhase.completed,
        activeConcepts: const ISetConst({}),
      );
    }
  }

  void _disposePlayer() {
    _positionSub?.cancel();
    _positionSub = null;
    _playerStateSub?.cancel();
    _playerStateSub = null;
    _player?.dispose();
    _player = null;
    _timestampedConceptsList = const [];
  }
}

/// StreamAudioSource subclass that reads from in-memory bytes.
///
/// Avoids writing temp files to disk. Suitable for short narrations
/// (~90s at 128kbps ≈ 1.4 MB).
class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes);

  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final effectiveEnd = end ?? _bytes.length;

    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: effectiveEnd - effectiveStart,
      offset: effectiveStart,
      stream: Stream.value(_bytes.sublist(effectiveStart, effectiveEnd)),
      contentType: 'audio/mpeg',
    );
  }
}
