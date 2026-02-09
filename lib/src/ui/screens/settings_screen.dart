import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/notification_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _outlineUrlController;
  late final TextEditingController _outlineKeyController;
  late final TextEditingController _anthropicKeyController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(settingsProvider);
    _outlineUrlController = TextEditingController(text: config.outlineApiUrl);
    _outlineKeyController = TextEditingController(text: config.outlineApiKey);
    _anthropicKeyController =
        TextEditingController(text: config.anthropicApiKey);
  }

  @override
  void dispose() {
    _outlineUrlController.dispose();
    _outlineKeyController.dispose();
    _anthropicKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(settingsProvider);
    final repo = ref.watch(settingsRepositoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Outline Wiki', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _outlineUrlController,
            decoration: InputDecoration(
              labelText: 'API URL',
              hintText: 'https://wiki.example.com',
              border: const OutlineInputBorder(),
              suffixIcon: config.outlineApiUrl.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setOutlineApiUrl(value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outlineKeyController,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: config.outlineApiKey.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            obscureText: true,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setOutlineApiKey(value),
          ),
          const SizedBox(height: 24),
          Text('Anthropic (Claude)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _anthropicKeyController,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-ant-...',
              border: const OutlineInputBorder(),
              suffixIcon: config.anthropicApiKey.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            obscureText: true,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setAnthropicApiKey(value),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    config.isFullyConfigured
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    color: config.isFullyConfigured
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      config.isFullyConfigured
                          ? 'All API keys configured'
                          : 'Configure API keys to get started',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Notifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Review reminders'),
            subtitle: const Text('Daily notification when concepts are due'),
            value: repo.getNotificationsEnabled(),
            onChanged: (value) async {
              if (value) {
                final service = ref.read(notificationServiceProvider);
                await service.requestPermissions();
              }
              await repo.setNotificationsEnabled(value);
              setState(() {});
            },
          ),
          if (repo.getNotificationsEnabled())
            ListTile(
              title: const Text('Reminder time'),
              subtitle: Text(_formatHour(repo.getReminderHour())),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: repo.getReminderHour(),
                    minute: 0,
                  ),
                );
                if (picked != null) {
                  await repo.setReminderHour(picked.hour);
                  setState(() {});
                }
              },
            ),
          const SizedBox(height: 24),
          Text('Cloud Sync', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable cloud sync'),
            subtitle: const Text('Sync graph to Firestore for cross-device access'),
            value: repo.getUseFirestore(),
            onChanged: (value) async {
              await repo.setUseFirestore(value);
              // Trigger provider rebuild by invalidating settings
              ref.invalidate(settingsProvider);
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
          Text('Outline Sync', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Auto-check on launch'),
            subtitle: const Text('Check for wiki updates when the app opens'),
            value: repo.getAutoCheckOnLaunch(),
            onChanged: (value) async {
              await repo.setAutoCheckOnLaunch(value);
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _lastSyncLabel(repo.getLastSyncTimestamp()),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  String _lastSyncLabel(String? timestamp) {
    if (timestamp == null) return 'Never synced';
    final date = DateTime.tryParse(timestamp);
    if (date == null) return 'Never synced';
    final diff = DateTime.now().toUtc().difference(date);
    if (diff.inMinutes < 1) return 'Last synced: just now';
    if (diff.inHours < 1) return 'Last synced: ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last synced: ${diff.inHours}h ago';
    return 'Last synced: ${diff.inDays}d ago';
  }
}
