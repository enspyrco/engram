import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/providers/settings_provider.dart';
import 'src/services/notification_service.dart';
import 'src/storage/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final appDir = await getApplicationDocumentsDirectory();
  final dataDir = '${appDir.path}/engram';

  // Initialize Firebase if cloud sync is enabled
  final settingsRepo = SettingsRepository(prefs);
  if (settingsRepo.getUseFirestore()) {
    await Firebase.initializeApp();
  }

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dataDirProvider.overrideWithValue(dataDir),
      ],
      child: const EngramApp(),
    ),
  );
}
