import 'package:engram/src/models/narration_session.dart';
import 'package:engram/src/providers/narration_provider.dart';
import 'package:engram/src/ui/widgets/narration_controls.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NarrationControls', () {
    Widget buildApp({NarrationSession session = const NarrationSession()}) {
      return ProviderScope(
        overrides: [
          narrationProvider.overrideWith(() => _FakeNarrationNotifier(session)),
        ],
        child: const MaterialApp(home: Scaffold(body: NarrationControls())),
      );
    }

    testWidgets('shows idle state when no narration active', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('No narration active'), findsOneWidget);
    });

    testWidgets('shows generating indicator during script generation', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          session: const NarrationSession(
            phase: NarrationPhase.generatingScript,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Generating script...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows synthesizing indicator during audio synthesis', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          session: const NarrationSession(
            phase: NarrationPhase.synthesizingAudio,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Synthesizing audio...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows play button when ready', (tester) async {
      await tester.pumpWidget(
        buildApp(session: const NarrationSession(phase: NarrationPhase.ready)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows pause button when playing', (tester) async {
      await tester.pumpWidget(
        buildApp(
          session: const NarrationSession(
            phase: NarrationPhase.playing,
            durationSeconds: 30.0,
            positionSeconds: 10.0,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('shows play button when paused', (tester) async {
      await tester.pumpWidget(
        buildApp(
          session: const NarrationSession(
            phase: NarrationPhase.paused,
            durationSeconds: 30.0,
            positionSeconds: 15.0,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows error message on error', (tester) async {
      await tester.pumpWidget(
        buildApp(
          session: const NarrationSession(
            phase: NarrationPhase.error,
            errorMessage: 'API key missing',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('API key missing'), findsOneWidget);
    });

    testWidgets('shows stop button during playback phases', (tester) async {
      await tester.pumpWidget(
        buildApp(
          session: const NarrationSession(
            phase: NarrationPhase.playing,
            durationSeconds: 30.0,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('shows progress bar during playback', (tester) async {
      await tester.pumpWidget(
        buildApp(
          session: const NarrationSession(
            phase: NarrationPhase.playing,
            durationSeconds: 60.0,
            positionSeconds: 30.0,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
    });
  });
}

class _FakeNarrationNotifier extends NarrationNotifier {
  _FakeNarrationNotifier(this._initialSession);

  final NarrationSession _initialSession;

  @override
  NarrationSession build() => _initialSession;
}
