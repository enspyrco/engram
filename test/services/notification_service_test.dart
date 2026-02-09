import 'package:engram/src/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:timezone/timezone.dart' as tz;

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class FakeNotificationDetails extends Fake implements NotificationDetails {}

class FakeTZDateTime extends Fake implements tz.TZDateTime {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(FakeNotificationDetails());
    registerFallbackValue(FakeTZDateTime());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
  });

  group('NotificationService', () {
    late MockFlutterLocalNotificationsPlugin mockPlugin;
    late NotificationService service;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      service = NotificationService.withPlugin(mockPlugin);
    });

    test('initialize calls plugin.initialize', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);

      await service.initialize();

      verify(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).called(1);
    });

    test('initialize only runs once', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).thenAnswer((_) async => true);

      await service.initialize();
      await service.initialize();

      verify(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).called(1);
    });

    test('cancelAll delegates to plugin', () async {
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});

      await service.cancelAll();

      verify(() => mockPlugin.cancelAll()).called(1);
    });

    test('scheduleReviewReminder cancels then schedules', () async {
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});
      when(() => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          )).thenAnswer((_) async {});

      await service.scheduleReviewReminder(
        hour: 9,
        title: '3-day streak!',
        body: 'Keep it going — 5 concepts due.',
      );

      verify(() => mockPlugin.cancelAll()).called(1);
      verify(() => mockPlugin.zonedSchedule(
            id: 1,
            title: '3-day streak!',
            body: 'Keep it going — 5 concepts due.',
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          )).called(1);
    });

    test('scheduleReviewReminder only cancels when skipSchedule is true',
        () async {
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});

      await service.scheduleReviewReminder(
        hour: 9,
        skipSchedule: true,
      );

      verify(() => mockPlugin.cancelAll()).called(1);
      verifyNever(() => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          ));
    });

    test('scheduleReviewReminder uses provided title and body', () async {
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});
      when(() => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          )).thenAnswer((_) async {});

      await service.scheduleReviewReminder(
        hour: 9,
        title: 'Welcome back!',
        body: 'Quick review to refresh? 10 concepts waiting.',
      );

      verify(() => mockPlugin.zonedSchedule(
            id: 1,
            title: 'Welcome back!',
            body: 'Quick review to refresh? 10 concepts waiting.',
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          )).called(1);
    });
  });
}
