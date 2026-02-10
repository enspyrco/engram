import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyOutlineApiUrl = 'outline_api_url';
  static const _keyOutlineApiKey = 'outline_api_key';
  static const _keyAnthropicApiKey = 'anthropic_api_key';
  static const _keyLastSyncTimestamp = 'last_sync_timestamp';
  static const _keyAutoCheckOnLaunch = 'auto_check_on_launch';
  static const _keyIngestedCollectionIds = 'ingested_collection_ids';
  static const _keyNotificationsEnabled = 'notifications_enabled';
  static const _keyReminderHour = 'reminder_hour';
  static const _keyLastSessionDate = 'last_session_date';
  static const _keyCurrentStreak = 'current_streak';
  static const _keyLongestStreak = 'longest_streak';

  EngramConfig load() {
    return EngramConfig(
      outlineApiUrl: _prefs.getString(_keyOutlineApiUrl) ?? '',
      outlineApiKey: _prefs.getString(_keyOutlineApiKey) ?? '',
      anthropicApiKey: _prefs.getString(_keyAnthropicApiKey) ?? '',
    );
  }

  Future<void> save(EngramConfig config) async {
    await Future.wait([
      _prefs.setString(_keyOutlineApiUrl, config.outlineApiUrl),
      _prefs.setString(_keyOutlineApiKey, config.outlineApiKey),
      _prefs.setString(_keyAnthropicApiKey, config.anthropicApiKey),
    ]);
  }

  Future<void> setOutlineApiUrl(String value) =>
      _prefs.setString(_keyOutlineApiUrl, value);

  Future<void> setOutlineApiKey(String value) =>
      _prefs.setString(_keyOutlineApiKey, value);

  Future<void> setAnthropicApiKey(String value) =>
      _prefs.setString(_keyAnthropicApiKey, value);

  // --- Sync settings ---

  String? getLastSyncTimestamp() =>
      _prefs.getString(_keyLastSyncTimestamp);

  Future<void> setLastSyncTimestamp(String value) =>
      _prefs.setString(_keyLastSyncTimestamp, value);

  bool getAutoCheckOnLaunch() =>
      _prefs.getBool(_keyAutoCheckOnLaunch) ?? true;

  Future<void> setAutoCheckOnLaunch(bool value) =>
      _prefs.setBool(_keyAutoCheckOnLaunch, value);

  List<String> getIngestedCollectionIds() =>
      _prefs.getStringList(_keyIngestedCollectionIds) ?? [];

  Future<void> addIngestedCollectionId(String id) async {
    final ids = getIngestedCollectionIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await _prefs.setStringList(_keyIngestedCollectionIds, ids);
    }
  }

  // --- Notification settings ---

  bool getNotificationsEnabled() =>
      _prefs.getBool(_keyNotificationsEnabled) ?? false;

  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_keyNotificationsEnabled, value);

  int getReminderHour() => _prefs.getInt(_keyReminderHour) ?? 9;

  Future<void> setReminderHour(int value) =>
      _prefs.setInt(_keyReminderHour, value);

  // --- Session tracking ---

  String? getLastSessionDate() => _prefs.getString(_keyLastSessionDate);

  Future<void> setLastSessionDate(String value) =>
      _prefs.setString(_keyLastSessionDate, value);

  int getCurrentStreak() => _prefs.getInt(_keyCurrentStreak) ?? 0;

  Future<void> setCurrentStreak(int value) =>
      _prefs.setInt(_keyCurrentStreak, value);

  int getLongestStreak() => _prefs.getInt(_keyLongestStreak) ?? 0;

  Future<void> setLongestStreak(int value) =>
      _prefs.setInt(_keyLongestStreak, value);
}
