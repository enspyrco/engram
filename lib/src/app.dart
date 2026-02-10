import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'ui/navigation_shell.dart';
import 'ui/screens/sign_in_screen.dart';

class EngramApp extends StatelessWidget {
  const EngramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Engram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const _AuthGate(),
    );
  }
}

/// Shows [SignInScreen] when unauthenticated, [NavigationShell] when signed in.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const SignInScreen();
        return NavigationShell(key: navigationShellKey);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SignInScreen(),
    );
  }
}
