import 'package:material_ui/material_ui.dart';

import '../graph_lab_screen.dart';
import 'glow_lab_tab.dart';
import 'narration_lab_tab.dart';
import 'overlay_lab_tab.dart';
import 'widget_lab_tab.dart';

/// Top-level lab shell with tabs for each visual subsystem.
///
/// No providers, no auth, no network — just widgets and painters with hardcoded
/// test data for rapid hot-reload iteration.
class VisualLabScreen extends StatelessWidget {
  const VisualLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visual Lab'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.hub), text: 'Graph'),
              Tab(icon: Icon(Icons.layers), text: 'Overlays'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'Glow'),
              Tab(icon: Icon(Icons.widgets), text: 'Widgets'),
              Tab(icon: Icon(Icons.record_voice_over), text: 'Narration'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            GraphLabScreen(),
            OverlayLabTab(),
            GlowLabTab(),
            WidgetLabTab(),
            NarrationLabTab(),
          ],
        ),
      ),
    );
  }
}
