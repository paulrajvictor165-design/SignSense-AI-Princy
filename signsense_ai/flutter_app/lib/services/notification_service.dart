import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // flutter_local_notifications v18: DarwinInitializationSettings replaces
    // IOSInitializationSettings. Callback signatures are updated.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      // ✅ v18 requires onDidReceiveNotificationResponse (replaces onSelectNotification).
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap — no-op for SignSense AI (voice app).
      },
    );
  }

  static Future<void> showSOSNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'sos_channel',
      'SOS Alerts',
      channelDescription: 'Emergency SOS notifications',
      importance: Importance.max,
      priority: Priority.high,
      // ✅ RawResourceAndroidNotificationSound requires the file to exist in
      // android/app/src/main/res/raw/sos_alert.mp3 — uses default if absent.
      sound: RawResourceAndroidNotificationSound('sos_alert'),
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      'SOS Alert Sent',
      'Your emergency contact has been notified with your location.',
      notificationDetails,
    );
  }

  static Future<void> showDetectionNotification(String label) async {
    const androidDetails = AndroidNotificationDetails(
      'detection_channel',
      'Detection Alerts',
      channelDescription: 'Object and hazard detection notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1,
      'SignSense Alert',
      label,
      notificationDetails,
    );
  }
}
