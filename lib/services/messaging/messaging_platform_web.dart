// messaging_platform_web.dart — implémentation réelle pour le web.
//
// Le blocage initial (firebase_messaging_web 3.5.18 ne compilait plus avec
// les Dart SDK récents — erreurs "PromiseJsImpl not found") a été résolu en
// mettant à jour firebase_core/firebase_messaging vers des versions plus
// récentes (voir pubspec.yaml). L'API Dart est la même que côté mobile
// (voir messaging_platform_io.dart) ; seule différence : la gestion des
// messages en arrière-plan est déléguée entièrement au service worker JS
// (web/firebase-messaging-sw.js), pas à un isolate Dart comme sur natif —
// FirebaseMessaging.onBackgroundMessage() n'est donc pas appelé ici.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../local_notification_service.dart';
import '../api.service.dart';

void _onForegroundMessage(RemoteMessage message) {
  debugPrint('📬 [Web] Foreground message: ${message.messageId}');
  LocalNotificationService.showNotification(
    title: message.notification?.title ?? 'Notification',
    body: message.notification?.body ?? '',
  );
}

void _onMessageOpenedApp(RemoteMessage message) {
  debugPrint('🔗 [Web] Message opened: ${message.messageId}');
  final link = message.data['link'];
  if (link != null) {
    debugPrint('🔗 Navigate to: $link');
  }
}

class PlatformMessaging {
  /// Initialise FCM sur le web et retourne le token obtenu (ou null en cas
  /// d'échec — notamment tant que `AppConstants.fcmVapidKey` n'est pas
  /// remplacée par la vraie clé VAPID depuis la Console Firebase).
  static Future<String?> initialize({String? vapidKey}) async {
    if (vapidKey == null || vapidKey.isEmpty || vapidKey.contains('REMPLACER')) {
      debugPrint('⚠️ [Web] Clé VAPID non configurée — notifications push web désactivées. '
          'Console Firebase → Paramètres du projet → Cloud Messaging → Certificats web push.');
      return null;
    }

    try {
      debugPrint('🌐 [Web] Initializing FCM...');
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 [Web] FCM permission status: ${settings.authorizationStatus}');

      final token = await messaging.getToken(vapidKey: vapidKey);

      if (token != null) {
        debugPrint('🎫 [Web] FCM Token obtenu, stocké en attente de l\'authentification');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_fcm_token', token);
        } catch (_) {}
      } else {
        debugPrint('⚠️ [Web] FCM Token null — notifications push impossibles');
      }

      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 [Web] FCM Token rafraîchi');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_fcm_token', newToken);
          await ApiService().registerFcmToken(newToken);
        } catch (_) {}
      });

      // Messages reçus onglet ouvert et au premier plan — l'arrière-plan est
      // géré par web/firebase-messaging-sw.js, pas ici.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      debugPrint('✅ [Web] FCM initialized');
      return token;
    } catch (e, stack) {
      debugPrint('⚠️ [Web] FCM init failed: $e\n$stack');
      return null;
    }
  }
}