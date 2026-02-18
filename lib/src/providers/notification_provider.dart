import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/streak.dart';
import '../services/notification_service.dart';
import 'clock_provider.dart';
import 'dashboard_stats_provider.dart';
import 'settings_provider.dart';
import 'sync_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Listens to dashboard stats, sync status, and streak data, then
/// reschedules the daily notification with context-aware copy.
final notificationUpdaterProvider = Provider<void>((ref) {
  final stats = ref.watch(dashboardStatsProvider);
  final service = ref.read(notificationServiceProvider);
  final settingsRepo = ref.read(settingsRepositoryProvider);

  if (!settingsRepo.getNotificationsEnabled()) return;

  // Read (not watch) sync status to avoid cascading rebuilds during initState.
  // The dashboardStatsProvider watch already covers the reactive path:
  // new docs ingested → graph changes → stats change → this provider re-runs.
  final syncStatus = ref.read(syncProvider);
  final hasNewConcepts = syncStatus.newCollections.isNotEmpty;

  final absence = inspectAbsence(
    lastSessionDateIso: settingsRepo.getLastSessionDate(),
    now: ref.read(clockProvider)(),
  );

  final copy = buildNotificationCopy(
    dueCount: stats.dueCount,
    daysSinceLastSession: absence?.daysSinceLastSession,
    currentStreak: settingsRepo.getCurrentStreak(),
    hasNewConcepts: hasNewConcepts,
  );

  final hour = settingsRepo.getReminderHour();
  service.scheduleReviewReminder(
    hour: hour,
    title: copy.title,
    body: copy.body,
    skipSchedule: copy.skip,
  );
});
