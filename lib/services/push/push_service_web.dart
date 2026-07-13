import 'package:firebase_messaging/firebase_messaging.dart';

class PushService {
  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        // Web Notification API gestita dal service worker
      }
    });
  }

  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken(
        vapidKey: 'TUA_VAPID_KEY',
      );
    } catch (e) {
      return null;
    }
  }

  static void onMessageOpenedApp(
      void Function(Map<String, dynamic> data) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handler(message.data);
    });
  }
}
