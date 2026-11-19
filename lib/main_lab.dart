import 'package:material_ui/material_ui.dart';

import 'src/ui/screens/lab/visual_lab_screen.dart';

/// Standalone entry point for the Visual Lab.
///
/// Launches without Firebase, auth, or Riverpod — just a MaterialApp with dark
/// theme and the lab screen. Use for sub-second hot-reload iteration on custom
/// painters and visual widgets.
///
/// ```bash
/// flutter run -d macos -t lib/main_lab.dart
/// ```
void main() {
  runApp(
    MaterialApp(
      title: 'Engram Visual Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const VisualLabScreen(),
    ),
  );
}
