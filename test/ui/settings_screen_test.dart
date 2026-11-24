import 'package:engram/src/providers/settings_provider.dart';
import 'package:engram/src/ui/screens/settings_screen.dart';
import 'package:material_ui/material_ui.dart';
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
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      );
    }

    testWidgets('renders all text fields', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Outline Wiki'), findsOneWidget);
      expect(find.text('Anthropic (Claude)'), findsOneWidget);
      expect(find.text('ElevenLabs (Narration)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'API URL'), findsOneWidget);
      // Three API Key fields (Outline + Anthropic + ElevenLabs)
      expect(find.widgetWithText(TextField, 'API Key'), findsNWidgets(3));
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

    testWidgets('offers no way to join a wiki group', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.text('Social'), findsNothing);
      expect(find.text('Friend discovery'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final repo = container.read(settingsRepositoryProvider);
      expect(repo.getFriendDiscoveryEnabled(), isFalse);
    });
  });
}
