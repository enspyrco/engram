import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/extraction_service.dart';
import '../services/outline_client.dart';
import 'settings_provider.dart';

final outlineClientProvider = Provider<OutlineClient>((ref) {
  final config = ref.watch(settingsProvider);
  return OutlineClient(
    apiUrl: config.outlineApiUrl,
    apiKey: config.outlineApiKey,
  );
});

final extractionServiceProvider = Provider<ExtractionService>((ref) {
  final config = ref.watch(settingsProvider);
  return ExtractionService(apiKey: config.anthropicApiKey);
});
