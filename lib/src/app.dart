import 'package:flutter/material.dart';

import 'ui/navigation_shell.dart';

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
      home: NavigationShell(key: navigationShellKey),
    );
  }
}
