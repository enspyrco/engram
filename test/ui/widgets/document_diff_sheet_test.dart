import 'package:engram/src/providers/document_diff_provider.dart';
import 'package:engram/src/ui/widgets/document_diff_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A test notifier that lets us set state directly.
class _TestDiffNotifier extends DocumentDiffNotifier {
  _TestDiffNotifier(this._initial);
  final DocumentDiffState _initial;

  @override
  DocumentDiffState build() => _initial;

  @override
  Future<void> fetchDiff({required String documentId}) async {}
}

void main() {
  group('DocumentDiffSheet', () {
    Widget buildSheet(DocumentDiffState initialState) {
      return ProviderScope(
        overrides: [
          documentDiffProvider.overrideWith(
            () => _TestDiffNotifier(initialState),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DocumentDiffSheet())),
      );
    }

    testWidgets('shows spinner when loading', (tester) async {
      await tester.pumpWidget(buildSheet(const DocumentDiffLoading()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading diff...'), findsOneWidget);
    });

    testWidgets('shows diff when loaded', (tester) async {
      await tester.pumpWidget(
        buildSheet(
          DocumentDiffLoaded(
            oldText: '# Original',
            newText: '# Updated\nNew line.',
            ingestedAt: DateTime.utc(2026, 2, 17, 10),
          ),
        ),
      );

      // Legend items
      expect(find.text('Added'), findsOneWidget);
      expect(find.text('Removed'), findsOneWidget);

      // Subtitle with locale-aware revision date (intl DateFormat.yMMMd)
      expect(find.textContaining('Since'), findsOneWidget);
      expect(find.textContaining('Feb'), findsOneWidget);

      // The PrettyDiffText renders as RichText — verify it's present
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('shows error message on error', (tester) async {
      await tester.pumpWidget(
        buildSheet(const DocumentDiffError('Network timeout')),
      );

      expect(find.textContaining('Network timeout'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows nothing meaningful when idle', (tester) async {
      await tester.pumpWidget(buildSheet(const DocumentDiffIdle()));

      // Idle state shows nothing — just an empty container
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}
