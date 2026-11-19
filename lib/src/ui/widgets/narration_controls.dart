import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/narration_session.dart';
import '../../providers/graph_structure_provider.dart';
import '../../providers/narration_provider.dart';

/// Compact narration playback controls.
///
/// Shows phase-appropriate UI: progress indicator during generation, play/pause
/// + seekable slider during playback, error message on failure.
/// Designed to be used as a bottom sheet or inline widget.
class NarrationControls extends ConsumerWidget {
  const NarrationControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(narrationProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: switch (session.phase) {
        NarrationPhase.idle => const _IdleState(),
        NarrationPhase.generatingScript => const _LoadingState(
          message: 'Generating script...',
        ),
        NarrationPhase.synthesizingAudio => const _LoadingState(
          message: 'Synthesizing audio...',
        ),
        NarrationPhase.ready ||
        NarrationPhase.playing ||
        NarrationPhase.paused ||
        NarrationPhase.completed => _PlaybackControls(session: session),
        NarrationPhase.error => _ErrorState(message: session.errorMessage),
      },
    );
  }
}

class _IdleState extends StatelessWidget {
  const _IdleState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No narration active', style: TextStyle(color: Colors.grey)),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(message),
      ],
    );
  }
}

class _PlaybackControls extends ConsumerWidget {
  const _PlaybackControls({required this.session});

  final NarrationSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = session.phase == NarrationPhase.playing;
    final duration = session.durationSeconds;
    final position = session.positionSeconds.clamp(0.0, duration);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Seek slider
        if (duration > 0)
          Slider(
            value: position,
            max: duration,
            onChanged: (value) {
              ref
                  .read(narrationProvider.notifier)
                  .seek(Duration(milliseconds: (value * 1000).round()));
            },
          ),
        // Time labels + controls
        Row(
          children: [
            Text(
              _formatTime(position),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Spacer(),
            // Play/Pause button
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 32,
              onPressed: () {
                final notifier = ref.read(narrationProvider.notifier);
                isPlaying ? notifier.pause() : notifier.play();
              },
            ),
            // Stop button
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () => ref.read(narrationProvider.notifier).reset(),
            ),
            const Spacer(),
            Text(
              _formatTime(duration),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        // Active concepts indicator (resolved to human-readable names)
        if (session.activeConcepts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _ActiveConceptsLabel(
              conceptIds: session.activeConcepts.toList(),
            ),
          ),
      ],
    );
  }

  static String _formatTime(double seconds) {
    final mins = seconds ~/ 60;
    final secs = (seconds % 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

/// Resolves concept IDs to human-readable names via [graphStructureProvider].
class _ActiveConceptsLabel extends ConsumerWidget {
  const _ActiveConceptsLabel({required this.conceptIds});

  final List<String> conceptIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(graphStructureProvider);
    final nameMap = {
      if (graph != null)
        for (final c in graph.concepts) c.id: c.name,
    };
    final names = conceptIds.map((id) => nameMap[id] ?? id).join(', ');

    return Text(
      names,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.cyan,
        fontStyle: FontStyle.italic,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.red),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
