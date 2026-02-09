import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/config.dart';
import '../storage/settings_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override in main with actual instance'),
);

final dataDirProvider = Provider<String>(
  (_) => throw UnimplementedError('Override in main with actual path'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final settingsProvider =
    NotifierProvider<SettingsNotifier, EngramConfig>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<EngramConfig> {
  @override
  EngramConfig build() {
    final repo = ref.watch(settingsRepositoryProvider);
    final dataDir = ref.watch(dataDirProvider);
    return repo.load().copyWith(dataDir: dataDir);
  }

  Future<void> setOutlineApiUrl(String value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setOutlineApiUrl(value);
    state = state.copyWith(outlineApiUrl: value);
  }

  Future<void> setOutlineApiKey(String value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setOutlineApiKey(value);
    state = state.copyWith(outlineApiKey: value);
  }

  Future<void> setAnthropicApiKey(String value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setAnthropicApiKey(value);
    state = state.copyWith(anthropicApiKey: value);
  }

}
