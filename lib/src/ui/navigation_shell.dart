import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_status.dart';
import '../providers/crdt_sync_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/graph_lab_screen.dart';
import 'screens/ingest_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/settings_screen.dart';

/// Global key to access NavigationShell state for notification deep-linking.
final navigationShellKey = GlobalKey<NavigationShellState>();

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => NavigationShellState();
}

class NavigationShellState extends ConsumerState<NavigationShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const _screens = <Widget>[
    GraphLabScreen(),
    DashboardScreen(),
    QuizScreen(),
    IngestScreen(),
    FriendsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdatesIfEnabled();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationUpdaterProvider);
      // Start CRDT sync: immediate push+pull, then periodic every 5 min.
      ref.read(crdtSyncProvider.notifier).startPeriodicSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdatesIfEnabled();
      // Sync on resume — pull any remote changes while we were backgrounded.
      ref.read(crdtSyncProvider.notifier).sync();
    }
    if (state == AppLifecycleState.paused) {
      // Push pending changes before going to background.
      ref.read(crdtSyncProvider.notifier).sync();
    }
  }

  void _checkForUpdatesIfEnabled() {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      if (repo.getAutoCheckOnLaunch()) {
        ref.read(syncProvider.notifier).checkForUpdates();
      }
    } on FlutterError {
      // ref.read() does an ancestor lookup that fails if the widget is
      // deactivated (removed from tree but not yet disposed). This can
      // happen when a lifecycle "resumed" event arrives during rebuild.
    }
  }

  /// Navigate to a tab by index. Called from notification tap handler.
  void navigateToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for sync completion to refresh dashboard
    ref.listen<SyncStatus>(syncProvider, (prev, next) {
      if (prev?.phase == SyncPhase.syncing &&
          next.phase == SyncPhase.upToDate) {
        // Sync completed — graph is already updated by SyncNotifier,
        // dashboard stats will auto-rebuild via provider chain.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sync complete')));
      }
    });

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Graph Lab',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Quiz',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Ingest',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Social',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
