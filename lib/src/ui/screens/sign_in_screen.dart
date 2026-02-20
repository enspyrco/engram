import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../widgets/sign_in_button.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(firebaseAuthProvider);
      final firestore = ref.read(firestoreProvider);
      final googleSignIn = ref.read(googleSignInProvider);
      await signInWithGoogle(auth,
          firestore: firestore, googleSignIn: googleSignIn);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(firebaseAuthProvider);
      final firestore = ref.read(firestoreProvider);
      await signInWithApple(auth, firestore: firestore);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('Engram', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Learn your wiki with spaced repetition',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              if (_loading)
                const CircularProgressIndicator()
              else ...[
                SignInButton(
                  label: 'Continue with Google',
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  onPressed: _handleGoogleSignIn,
                ),
                if (isApplePlatform) ...[
                  const SizedBox(height: 12),
                  SignInButton(
                    label: 'Continue with Apple',
                    icon: const Icon(Icons.apple, size: 24),
                    backgroundColor: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    foregroundColor: theme.brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    onPressed: _handleAppleSignIn,
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
