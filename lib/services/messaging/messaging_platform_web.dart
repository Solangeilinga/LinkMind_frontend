// messaging_platform_web.dart — stub pour le web.
//
// firebase_messaging_web 3.5.18 (figé par contrainte dans pubspec.yaml) ne
// compile plus avec les Dart SDK récents (erreurs "PromiseJsImpl not found" /
// "handleThenable" lors du build Netlify) — l'ancien package utilise une API
// JS interop supprimée. Plutôt que de mettre à jour firebase_core/firebase_messaging
// en urgence (saut de version majeure, risqué pour le mobile sans tests), ce
// fichier isole complètement le web de `package:firebase_messaging` : aucun
// import ici, donc le code cassé n'entre jamais dans la compilation web.
//
// Conséquence : pas de notifications push sur la version web pour l'instant.
// À réactiver en basculant ce fichier vers la vraie implémentation une fois
// firebase_core/firebase_messaging mis à jour et testés sur toutes les
// plateformes (voir messaging_platform_io.dart pour l'implémentation mobile).
import 'package:flutter/foundation.dart';

class PlatformMessaging {
  static Future<String?> initialize({String? vapidKey}) async {
    debugPrint('ℹ️ Notifications push désactivées sur le web pour le moment.');
    return null;
  }
}
