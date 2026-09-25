import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'storage_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize the notification plugin
  static Future<void> initialize() async {
    if (!_isSupportedPlatform()) {
      debugPrint('⚠️ Notifications not supported on this platform');
      return;
    }

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const LinuxInitializationSettings linuxSettings =
          LinuxInitializationSettings(
            defaultActionName: 'Open notification',
          );

      InitializationSettings settings;
      
      if (kIsWeb) {
        settings = const InitializationSettings();
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        settings = const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          linux: linuxSettings,
        );
      } else {
        settings = const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );
      }

      await _notifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification tapped: ${details.payload}');
        },
      );
      
      debugPrint('✅ Notification service initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Notification service initialization failed: $e');
    }
  }

  static bool _isSupportedPlatform() {
    return !kIsWeb && 
           (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }

  /// Show a notification and automatically save it for the in-app NotificationScreen
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String type = 'appointment',
    String? payload,
    bool saveToHistory = true,
  }) async {
    // 1. Save locally to ensure reference list always has it
    if (saveToHistory) {
      await StorageService().saveLocalNotification(
        id: id,
        title: title,
        message: body,
        type: type,
      );
    }

    // 2. Fire system tray notification
    if (!_isSupportedPlatform()) {
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'smart_medical_channel',
            'Smart Medical Hub Notifications',
            channelDescription: 'Notifications from Smart Medical Hub',
            importance: Importance.high,
            priority: Priority.high,
          );

      const DarwinNotificationDetails iosDetails =
          DarwinNotificationDetails();

      const LinuxNotificationDetails linuxDetails =
          LinuxNotificationDetails(
            defaultActionName: 'Open',
          );

      NotificationDetails details;
      
      if (defaultTargetPlatform == TargetPlatform.linux) {
        details = const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          linux: linuxDetails,
        );
      } else {
        details = const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );
      }

      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to show system notification: $e');
    }
  }

  /// Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    try {
      // Fixed: Pass id using named argument
      await _notifications.cancel(id: id);
    } catch (e) {
      debugPrint('⚠️ Failed to cancel notification: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('⚠️ Failed to cancel all notifications: $e');
    }
  }
}