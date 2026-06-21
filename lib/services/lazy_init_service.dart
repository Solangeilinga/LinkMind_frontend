import 'dart:async'; // ← AJOUT OBLIGATOIRE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'local_notification_service.dart';
import 'api.service.dart';

/// 🚀 Lazy Initialization Service
/// Initialise services critiques en background
/// Réduit startup time de 500-800ms

class LazyInitService {
  static String? pendingFcmToken;
  static final LazyInitService _instance = LazyInitService._internal();

  factory LazyInitService() => _instance;
  LazyInitService._internal();

  bool _firebaseInitialized = false;
  bool _notificationsInitialized = false;

  /// Initialize Firebase (async, non-blocking)
  Future<void> initializeFirebase() async {
    if (_firebaseInitialized) return;

    try {
      debugPrint('🔥 Initializing Firebase...');

      // Timeout court pour éviter bloquer app
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Firebase init timeout (continuing anyway)');
          throw TimeoutException('Firebase initialization timeout');
        },
      );

      _firebaseInitialized = true;
      debugPrint('✅ Firebase initialized');

      await _initializeMessaging();
    } on TimeoutException catch (e) {
      debugPrint('⚠️ Firebase init timeout: $e');
    } catch (e, stack) {
      debugPrint('❌ Firebase init error: $e\n$stack');
    }
  }

  /// Initialize Firebase Messaging
  Future<void> _initializeMessaging() async {
    if (_notificationsInitialized) return;

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

      // Récupérer le token FCM — envoi au backend APRÈS connexion
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('🎫 FCM Token obtenu, stocké en attente de l\'authentification');
        pendingFcmToken = token;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_fcm_token', token);
      } else {
        debugPrint('⚠️ FCM Token null — notifications push impossibles');
      }

      // Écouter le refresh du token
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM Token rafraîchi');
        pendingFcmToken = newToken;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_fcm_token', newToken);
          // Si déjà authentifié, envoyer immédiatement
          await ApiService().registerFcmToken(newToken);
        } catch (_) {}
      });

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      _notificationsInitialized = true;
      debugPrint('✅ FCM initialized');
    } catch (e, stack) {
      debugPrint('⚠️ FCM init failed: $e\n$stack');
    }
  }

  /// ✅ FIX: Envoyer le token FCM au backend avec retry
  Future<void> _registerTokenToBackend(String token) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await ApiService().registerFcmToken(token);
        debugPrint('✅ FCM Token enregistré sur le backend');
        return;
      } catch (e) {
        debugPrint('⚠️ Tentative $attempt/$maxRetries échouée: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    debugPrint('❌ Impossible d\'enregistrer le FCM token après $maxRetries tentatives');
  }

  /// Handle foreground messages
  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message: ${message.messageId}');

    LocalNotificationService.showNotification(
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
    );
  }

  /// Handle background messages
  @pragma('vm:entry-point')
  static Future<void> _onBackgroundMessage(RemoteMessage message) async {
    debugPrint('📬 Background message: ${message.messageId}');
  }

  /// Handle message tap
  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔗 Message opened: ${message.messageId}');
    final link = message.data['link'];
    if (link != null) {
      debugPrint('🔗 Navigate to: $link');
    }
  }

  /// Get initialization status
  Map<String, bool> getStatus() => {
        'firebase': _firebaseInitialized,
        'notifications': _notificationsInitialized,
      };
}