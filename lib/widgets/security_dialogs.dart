import 'package:flutter/material.dart';
import '../utils/theme.dart';

class SecurityDialogs {
  static void showAccountLockedDialog(
    BuildContext context, {
    required int remainingMinutes,
    VoidCallback? onClose,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.lock, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Compte verrouillé'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trop de tentatives de connexion ont été détectées.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Veuillez réessayer dans $remainingMinutes minute${remainingMinutes > 1 ? 's' : ''}.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'C\'est une mesure de sécurité pour protéger votre compte.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onClose?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void showRateLimitedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trop de requêtes'),
        content: const Text(
          'Vous avez effectué trop d\'actions récemment. '
          'Veuillez patienter quelques minutes avant de réessayer.',
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void showSessionExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session expirée'),
        content: const Text(
          'Votre session a expiré pour des raisons de sécurité. Veuillez vous reconnecter.',
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Rediriger vers login
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Se reconnecter'),
          ),
        ],
      ),
    );
  }
}