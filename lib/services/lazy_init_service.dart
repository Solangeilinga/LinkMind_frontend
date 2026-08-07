import 'dart:async'; // ← AJOUT OBLIGATOIRE
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'messaging/messaging_platform.dart';
import '../utils/theme.dart' show AppConstants;

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

      // ⚠️ CORRECTION : sur Android, le plugin Gradle "Google Services" (lié à
      // google-services.json) enregistre déjà une FirebaseApp nommée
      // "[DEFAULT]" au démarrage natif, AVANT que ce code Dart ne s'exécute.
      // Appeler Firebase.initializeApp() ici levait alors systématiquement
      // [core/duplicate-app], et comme cette exception tombait dans le
      // `catch` générique ci-dessous, _initializeMessaging() n'était JAMAIS
      // appelée : les notifications push (FCM) ne s'initialisaient donc
      // jamais, sur aucun lancement de l'app.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Firebase init timeout (continuing anyway)');
            throw TimeoutException('Firebase initialization timeout');
          },
        );
      } else {
        debugPrint('ℹ️ Firebase déjà initialisé nativement (app "[DEFAULT]" existante)');
      }

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

    // ⚠️ Sur le web, `vapidKey` est OBLIGATOIRE : sans lui, getToken()
    // retourne null silencieusement (contrairement à mobile où il est ignoré).
    // Toute la logique réelle (permission, token, listeners) vit désormais
    // dans messaging/messaging_platform.dart, qui bascule automatiquement
    // entre l'implémentation mobile (Firebase) et le stub web — voir ce
    // fichier pour le détail de pourquoi le web est temporairement exclu.
    final token = await PlatformMessaging.initialize(
      vapidKey: kIsWeb ? AppConstants.fcmVapidKey : null,
    );

    if (token != null) {
      pendingFcmToken = token;
    }

    _notificationsInitialized = true;
  }

  /// Get initialization status
  Map<String, bool> getStatus() => {
        'firebase': _firebaseInitialized,
        'notifications': _notificationsInitialized,
      };
}