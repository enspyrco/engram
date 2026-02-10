import 'package:engram/src/providers/auth_provider.dart';
import 'package:engram/src/ui/screens/sign_in_screen.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignInScreen', () {
    late MockFirebaseAuth mockAuth;

    setUp(() {
      mockAuth = MockFirebaseAuth();
    });

    Widget buildApp() {
      return ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
        ],
        child: const MaterialApp(home: SignInScreen()),
      );
    }

    testWidgets('renders app title and tagline', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Engram'), findsOneWidget);
      expect(
        find.text('Learn your wiki with spaced repetition'),
        findsOneWidget,
      );
    });

    testWidgets('renders Google sign-in button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('renders Apple sign-in on Apple platforms', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        expect(find.text('Continue with Apple'), findsOneWidget);
      } else {
        expect(find.text('Continue with Apple'), findsNothing);
      }
    });

    testWidgets('renders brain icon', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.psychology), findsOneWidget);
    });
  });
}
