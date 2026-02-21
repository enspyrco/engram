import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/storage/settings_repository.dart';
import 'package:engram/src/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsScreen', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget buildApp() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dataDirProvider.overrideWithValue('/tmp/engram_test'),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      );
    }

    testWidgets('renders all text fields', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Outline Wiki'), findsOneWidget);
      expect(find.text('Anthropic (Claude)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'API URL'), findsOneWidget);
      // Two API Key fields (Outline + Anthropic)
      expect(find.widgetWithText(TextField, 'API Key'), findsNWidgets(2));
    });

    testWidgets('shows warning when keys not configured', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Configure API keys to get started'), findsOneWidget);
    });

    testWidgets('shows success when all keys configured', (tester) async {
      SharedPreferences.setMockInitialValues({
        'outline_api_url': 'https://wiki.example.com',
        'outline_api_key': 'key123',
        'anthropic_api_key': 'sk-ant-123',
      });
      prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('All API keys configured'), findsOneWidget);
    });

    testWidgets('entering text updates settings', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final urlField = find.widgetWithText(TextField, 'API URL');
      await tester.enterText(urlField, 'https://wiki.test.com');
      await tester.pump();

      // The provider should have updated
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final config = container.read(settingsProvider);
      expect(config.outlineApiUrl, 'https://wiki.test.com');
    });

    testWidgets('friend discovery toggle defaults to off', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Scroll down to reveal the Social section
      await tester.scrollUntilVisible(
        find.text('Social'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Social'), findsOneWidget);
      expect(find.text('Friend discovery'), findsOneWidget);
      expect(
        find.text('Discover teammates from your wiki group'),
        findsOneWidget,
      );

      // Default is off
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final repo = container.read(settingsRepositoryProvider);
      expect(repo.getFriendDiscoveryEnabled(), isFalse);
    });

    testWidgets('friend discovery toggle persists value', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Scroll down to reveal the Social section
      await tester.scrollUntilVisible(
        find.text('Friend discovery'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Find and tap the switch
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Friend discovery',
      );
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify persisted
      final repo = SettingsRepository(prefs);
      expect(repo.getFriendDiscoveryEnabled(), isTrue);
    });
  });
}
