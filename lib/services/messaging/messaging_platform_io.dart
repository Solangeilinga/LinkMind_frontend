// messaging_platform_io.dart — implémentation réelle (Android/iOS/desktop).
// Ce fichier importe firebase_messaging normalement : c'est sans risque, il
// n'est JAMAIS compilé pour le web (voir messaging_platform.dart).
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../local_notification_service.dart';
import '../api.service.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  debugPrint('📬 Background message: ${message.messageId}');
}

void _onForegroundMessage(RemoteMessage message) {
  debugPrint('📬 Foreground message: ${message.messageId}');
  LocalNotificationService.showNotification(
    title: message.notification?.title ?? 'Notification',
    body: message.notification?.body ?? '',
  );
}

void _onMessageOpenedApp(RemoteMessage message) {
  debugPrint('🔗 Message opened: ${message.messageId}');
  final link = message.data['link'];
  if (link != null) {
    debugPrint('🔗 Navigate to: $link');
  }
}

class PlatformMessaging {
  /// Initialise FCM et retourne le token obtenu (ou null en cas d'échec).
  static Future<String?> initialize({String? vapidKey}) async {
    try {
      debugPrint('📱 Initializing FCM...');
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('🔔 FCM permission status: ${settings.authorizationStatus}');

      final token = await messaging.getToken(vapidKey: vapidKey);

      if (token != null) {
        debugPrint('🎫 FCM Token obtenu, stocké en attente de l\'authentification');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_fcm_token', token);
        } catch (_) {}
      } else {
        debugPrint('⚠️ FCM Token null — notifications push impossibles');
      }

      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM Token rafraîchi');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_fcm_token', newToken);
          await ApiService().registerFcmToken(newToken);
        } catch (_) {}
      });

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      debugPrint('✅ FCM initialized');
      return token;
    } catch (e, stack) {
      debugPrint('⚠️ FCM init failed: $e\n$stack');
      return null;
    }
  }
}
