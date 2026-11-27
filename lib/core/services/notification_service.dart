import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages local scheduled notifications for Upcoming Moments.
abstract final class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  static bool _initialized = false;
  static String? _pendingEntryId;

  /// Broadcasts an `entryId` whenever the user taps an upcoming-moment
  /// notification while the app is running.
  static Stream<String> get onEntryTap => _tapController.stream;

  /// Returns and clears any `entryId` that launched the app from a terminated
  /// state via notification tap.
  static String? consumePendingEntryId() {
    final id = _pendingEntryId;
    _pendingEntryId = null;
    return id;
  }

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final entryId = _parseEntryId(response.payload);
        if (entryId != null) {
          _pendingEntryId = entryId;
          _tapController.add(entryId);
        }
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final entryId =
          _parseEntryId(launchDetails?.notificationResponse?.payload);
      if (entryId != null) _pendingEntryId = entryId;
    }

    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static int _startId(String entryId) => 'start:$entryId'.hashCode & 0x7FFFFFFF;
  static int _endId(String entryId) => 'end:$entryId'.hashCode & 0x7FFFFFFF;

  static String? _parseEntryId(String? payload) {
    if (payload == null || !payload.startsWith('upcoming:')) return null;
    return payload.substring('upcoming:'.length);
  }

  static Future<AndroidScheduleMode> _androidScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final canExact = await android.canScheduleExactNotifications();
      if (canExact == true) return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<void> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    if (!when.isAfter(DateTime.now())) return;
    try {
      await requestPermissions();
      final scheduled = tz.TZDateTime.from(when.toUtc(), tz.UTC);
      final mode = await _androidScheduleMode();
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'upcoming_moments',
            'Upcoming Moments',
            channelDescription:
                'Reminders when your planned moments start and end.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: mode,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  /// Schedules a notification at [when] letting the user know their moment
  /// has started.
  static Future<void> scheduleMomentStarted({
    required String entryId,
    required String title,
    required DateTime when,
  }) {
    return _scheduleZoned(
      id: _startId(entryId),
      title: 'Your Moment is Starting!',
      body: '"$title" is starting now. Have a great time!',
      when: when,
      payload: 'upcoming:$entryId',
    );
  }

  /// Schedules a notification at [when] reminding the user to add photos for
  /// their ended moment.
  static Future<void> scheduleMomentEnded({
    required String entryId,
    required String title,
    required DateTime when,
  }) {
    return _scheduleZoned(
      id: _endId(entryId),
      title: 'Your Moment has Ended!',
      body: 'Ready to add photos from "$title"?',
      when: when,
      payload: 'upcoming:$entryId',
    );
  }

  static Future<void> cancelMoment(String entryId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _startId(entryId));
      await _plugin.cancel(id: _endId(entryId));
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }
}
