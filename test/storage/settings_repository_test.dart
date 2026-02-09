import 'package:engram/src/storage/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepository', () {
    late SettingsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);
    });

    test('load returns empty config when no values saved', () {
      final config = repo.load();
      expect(config.outlineApiUrl, isEmpty);
      expect(config.outlineApiKey, isEmpty);
      expect(config.anthropicApiKey, isEmpty);
      expect(config.isFullyConfigured, isFalse);
    });

    test('save and load round-trips config', () async {
      final config = repo.load().copyWith(
            outlineApiUrl: 'https://wiki.example.com',
            outlineApiKey: 'ol_key_123',
            anthropicApiKey: 'sk-ant-123',
          );
      await repo.save(config);

      final loaded = repo.load();
      expect(loaded.outlineApiUrl, 'https://wiki.example.com');
      expect(loaded.outlineApiKey, 'ol_key_123');
      expect(loaded.anthropicApiKey, 'sk-ant-123');
      expect(loaded.isFullyConfigured, isTrue);
    });

    test('individual setters persist values', () async {
      await repo.setOutlineApiUrl('https://wiki.test.com');
      await repo.setOutlineApiKey('key_abc');
      await repo.setAnthropicApiKey('sk-ant-xyz');

      final config = repo.load();
      expect(config.outlineApiUrl, 'https://wiki.test.com');
      expect(config.outlineApiKey, 'key_abc');
      expect(config.anthropicApiKey, 'sk-ant-xyz');
    });

    test('isOutlineConfigured requires both url and key', () {
      final config = repo.load().copyWith(outlineApiUrl: 'https://example.com');
      expect(config.isOutlineConfigured, isFalse);

      final config2 = config.copyWith(outlineApiKey: 'key');
      expect(config2.isOutlineConfigured, isTrue);
    });
  });
}
