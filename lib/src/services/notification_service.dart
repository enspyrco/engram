import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../ui/navigation_shell.dart';

/// Result of building notification copy. If [skip] is true, no notification
/// should be scheduled.
typedef NotificationCopy = ({String title, String body, bool skip});

/// Pure function: determines notification title + body based on user context.
NotificationCopy buildNotificationCopy({
  required int dueCount,
  required int? daysSinceLastSession,
  required int currentStreak,
  required bool hasNewConcepts,
}) {
  // All caught up, nothing new → skip
  if (dueCount == 0 && !hasNewConcepts) {
    return (title: 'All caught up!', body: 'Nothing due today.', skip: true);
  }

  // New concepts available
  if (hasNewConcepts) {
    final extra = dueCount > 0 ? ' Plus $dueCount due for review.' : '';
    return (
      title: 'New concepts to explore',
      body: 'Fresh material from your wiki is ready.$extra',
      skip: false,
    );
  }

  // Long absence — comeback nudge
  if (daysSinceLastSession != null && daysSinceLastSession > 3) {
    return (
      title: 'Welcome back!',
      body:
          'Quick review to refresh? $dueCount concept${dueCount == 1 ? '' : 's'} waiting.',
      skip: false,
    );
  }

  // Active streak
  if (currentStreak >= 2) {
    return (
      title: '$currentStreak-day streak!',
      body: 'Keep it going — $dueCount concept${dueCount == 1 ? '' : 's'} due.',
      skip: false,
    );
  }

  // Default
  return (
    title: 'Time to review!',
    body: '$dueCount concept${dueCount == 1 ? '' : 's'} due for review.',
    skip: false,
  );
}

/// Callback for when a notification is tapped. Navigates to the Quiz tab.
void onNotificationTap(NotificationResponse response) {
  navigationShellKey.currentState?.navigateToTab(1); // Quiz tab
}

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  NotificationService.withPlugin(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'engram_review';
  static const _channelName = 'Review Reminders';
  static const _notificationId = 1;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open Engram',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      ),
      onDidReceiveNotificationResponse: onNotificationTap,
    );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    // Android 13+
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    // iOS / macOS
    final darwin =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >() ??
        _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
    if (darwin is IOSFlutterLocalNotificationsPlugin) {
      return await darwin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    if (darwin is MacOSFlutterLocalNotificationsPlugin) {
      return await darwin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true; // Linux / Windows — no permission needed
  }

  /// Schedule a daily notification at the given hour (local time).
  ///
  /// Pass [title] and [body] to customize the notification text.
  /// If [skipSchedule] is true, only cancels existing notifications.
  Future<void> scheduleReviewReminder({
    required int hour,
    String title = 'Time to review!',
    String body = '',
    bool skipSchedule = false,
  }) async {
    await cancelAll();

    if (skipSchedule) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
    );
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
