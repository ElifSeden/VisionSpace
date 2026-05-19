import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../navigation/app_navigator.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (error, stackTrace) {
    debugPrint('Background Firebase initialization skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  // Background message handling infrastructure.
  // When a data-only payload is received, we can show a local notification here if toggled on.
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Expose the plugin so other services can show notifications.
  FlutterLocalNotificationsPlugin get localNotificationsPlugin =>
      _localNotifications;

  static const String _prefLocalNotifications = 'pref_local_notifications';
  static const String _prefRemoteNotifications = 'pref_remote_notifications';

  Future<void> initialize({bool enableRemoteNotifications = true}) async {
    tz.initializeTimeZones();

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    if (!enableRemoteNotifications) return;

    // Request permissions for Android 13+ and iOS
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (error, stackTrace) {
      debugPrint('Remote notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Setup FCM foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showRemoteNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessageTap(initialMessage);
    }
  }

  Future<bool> get isLocalNotificationsEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefLocalNotifications) ?? true;
  }

  Future<void> setLocalNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefLocalNotifications, enabled);
    if (!enabled) {
      await cancelAllLocalNotifications();
    }
  }

  Future<bool> get isRemoteNotificationsEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefRemoteNotifications) ?? true;
  }

  Future<void> setRemoteNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefRemoteNotifications, enabled);
  }

  Future<void> scheduleOnboardingReminders(
    String title,
    String body,
    String recurringTitle,
    String recurringBody,
  ) async {
    final enabled = await isLocalNotificationsEnabled;
    if (!enabled) return;

    // 1. Shortly after onboarding (e.g., 2 minutes)
    await _localNotifications.zonedSchedule(
      id: 1,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(minutes: 2)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'auth_reminders',
          'Authentication Reminders',
          channelDescription: 'Reminders to sign in or create an account',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    // 2. Every 3 days reminder
    // Schedule the next 10 occurrences manually since flutter_local_notifications lacks a 3-day interval.
    final now = tz.TZDateTime.now(tz.local);
    for (int i = 1; i <= 10; i++) {
      await _localNotifications.zonedSchedule(
        id: 10 + i,
        title: recurringTitle,
        body: recurringBody,
        scheduledDate: now.add(Duration(days: 3 * i)),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'auth_reminders',
            'Authentication Reminders',
            channelDescription: 'Reminders to sign in or create an account',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAllLocalNotifications() async {
    await _localNotifications.cancelAll();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final designId = _designIdFromPayload(response.payload);
    if (designId == null) return;
    openGeneratedDesignFromNotification(designId);
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    final designId = _designIdFromData(message.data);
    if (designId == null) return;
    openGeneratedDesignFromNotification(designId);
  }

  Future<void> _showRemoteNotification(RemoteMessage message) async {
    final enabled = await isRemoteNotificationsEnabled;
    if (!enabled) return;

    final notification = message.notification;
    if (notification != null) {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        payload: _payloadFromData(message.data),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'ai_updates',
            'Design AI Updates',
            channelDescription:
                'Notifications for when your AI designs are ready',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  }
}

String? _payloadFromData(Map<String, dynamic> data) {
  final designId = _designIdFromData(data);
  if (designId == null) return null;
  return 'generated_design:$designId';
}

String? _designIdFromPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) return null;
  final trimmed = payload.trim();
  if (trimmed.startsWith('generated_design:')) {
    final value = trimmed.substring('generated_design:'.length).trim();
    return value.isEmpty ? null : value;
  }
  return trimmed;
}

String? _designIdFromData(Map<String, dynamic> data) {
  const keys = ['designId', 'generatedDesignId', 'design_id', 'projectId'];
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
