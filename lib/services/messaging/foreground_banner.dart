import 'package:flutter/material.dart';
import '../../main.dart' show rootNavigatorKey;

// Bannière in-app affichée pour un message FCM reçu au premier plan sur le
// web (voir messaging_platform_web.dart) — extraite dans son propre fichier
// pour rester facilement testable indépendamment de Firebase.
void showForegroundNotificationBanner({required String title, String body = ''}) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (body.isNotEmpty) Text(body),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ),
  );
}
