import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import 'api.service.dart';

// Définition des types d'erreur pour éviter les erreurs de compilation
enum SecurityErrorType {
  unauthorized,
  sessionExpired,
  accountLocked,
  accountRestricted,
  rateLimited,
  forbidden,
}

class SecurityException implements Exception {
  final String message;
  final SecurityErrorType type;
  final Map<String, dynamic>? data;
  
  SecurityException(this.message, this.type, {this.data});
  
  @override
  String toString() => message;
}

class SecurityService {
  static const _sessionTimeout = Duration(minutes: 60);
  static DateTime? _lastActivity;
  static Timer? _sessionTimer;
  static bool _isShowingDialog = false;
  static bool _isInitialized = false;

  /// Initialiser le service de sécurité
  static void init(BuildContext context) {
    if (_isInitialized) return;
    _isInitialized = true;
    
    _updateActivity();
    _startSessionTimer(context);
    _setupUserInteraction(context);
    
    // Vérifier l'état du compte au démarrage
    _checkAccountStatus(context);
  }

  /// Mettre à jour la dernière activité
  static void _updateActivity() {
    _lastActivity = DateTime.now();
  }

  /// Démarrer le timer de session
  static void _startSessionTimer(BuildContext context) {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkSession(context);
    });
  }

  /// Vérifier l'état de la session
  static void _checkSession(BuildContext context) {
    if (_lastActivity == null) return;
    
    final inactiveTime = DateTime.now().difference(_lastActivity!);
    if (inactiveTime > _sessionTimeout && !_isShowingDialog) {
      _showSessionTimeoutDialog(context);
    }
  }

  /// Vérifier l'état du compte
  static Future<void> _checkAccountStatus(BuildContext context) async {
    try {
      final user = await ApiService().get('/users/me');
      if (user['restricted'] == true && user['restrictedUntil'] != null) {
        final until = DateTime.parse(user['restrictedUntil']);
        if (until.isAfter(DateTime.now())) {
          if (context.mounted) {
            showRestrictionDialog(context, until);
          }
        }
      }
    } catch (e) {
      // Ignorer les erreurs, l'utilisateur n'est peut-être pas connecté
    }
  }

  /// Afficher le dialogue d'expiration de session
  static void _showSessionTimeoutDialog(BuildContext context) {
    _isShowingDialog = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Session expirée'),
        content: const Text(
          'Votre session a expiré pour des raisons de sécurité. '
          'Veuillez vous reconnecter pour continuer.'
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        actions: [
          TextButton(
            onPressed: () async {
              _isShowingDialog = false;
              Navigator.of(dialogContext).pop();
              await _logout(context);
            },
            child: const Text('Se reconnecter'),
          ),
        ],
      ),
    ).then((_) {
      _isShowingDialog = false;
    });
  }

  /// Déconnexion et redirection
  static Future<void> _logout(BuildContext context) async {
    try {
      await ApiService().logout();
    } catch (_) {}
    
    await ApiService().clearTokens();
    
    if (context.mounted) {
      // Utiliser une redirection avec go_router si disponible
      try {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(context).pushReplacementNamed('/login');
      } catch (e) {
        // Fallback
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  /// Configurer la détection des interactions utilisateur
  static void _setupUserInteraction(BuildContext context) {
    // Détecter les interactions sur l'écran via WidgetsBinding
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      // Note: Pour une détection complète, il faudrait un wrapper dans l'app principale
    });
  }

  /// Réinitialiser le timer
  static void _resetTimer(BuildContext context) {
    _sessionTimer?.cancel();
    _startSessionTimer(context);
  }

  /// Rafraîchir la session côté serveur
  static Future<void> refreshSession() async {
    try {
      await ApiService().get('/users/me');
      _updateActivity();
      return;
    } catch (e) {
      // Si c'est une erreur d'authentification, ne pas logger en erreur
      if (e is SecurityException && e.type == SecurityErrorType.unauthorized) {
        return;
      }
      debugPrint('⚠️ Session refresh failed: $e');
    }
  }

  /// Enregistrer une activité (pour détection comportements suspects)
  /// Temporairement désactivé car la route n'existe pas encore
  static Future<void> recordActivity({
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    // TODO: Implémenter la route dans le backend quand elle sera prête
    // Actuellement désactivé pour éviter les erreurs 404
    debugPrint('📝 Activity recorded (local): $type - ${metadata ?? {}}');
    return;
    
    /* Code original désactivé
    try {
      unawaited(ApiService().post('/users/activity', {
        'type': type,
        'metadata': metadata ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      // Ne pas afficher d'erreur pour éviter de polluer la console
    }
    */
  }

  /// Vérifier si le compte est restreint
  static Future<bool> isAccountRestricted() async {
    try {
      final user = await ApiService().get('/users/me');
      if (user['restricted'] == true && user['restrictedUntil'] != null) {
        final until = DateTime.parse(user['restrictedUntil']);
        return until.isAfter(DateTime.now());
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Obtenir la date de fin de restriction
  static Future<DateTime?> getRestrictionEndDate() async {
    try {
      final user = await ApiService().get('/users/me');
      if (user['restricted'] == true && user['restrictedUntil'] != null) {
        return DateTime.parse(user['restrictedUntil']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Afficher le dialogue de restriction
  static void showRestrictionDialog(BuildContext context, DateTime until) {
    // Ne pas afficher si déjà affiché
    if (_isShowingDialog) return;
    _isShowingDialog = true;
    
    final remainingDays = until.difference(DateTime.now()).inDays;
    final remainingHours = until.difference(DateTime.now()).inHours % 24;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('⚠️ Compte restreint'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre compte a été temporairement restreint en raison d\'une activité suspecte.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Restriction jusqu\'au : ${_formatDate(until)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (remainingDays > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '($remainingDays jour${remainingDays > 1 ? 's' : ''} restant${remainingDays > 1 ? 's' : ''})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
            else if (remainingHours > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '($remainingHours heure${remainingHours > 1 ? 's' : ''} restante${remainingHours > 1 ? 's' : ''})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Pendant cette période, certaines actions sont limitées :',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            const BulletPoint(text: 'Création de nouveaux posts'),
            const BulletPoint(text: 'Envoi de commentaires'),
            const BulletPoint(text: 'Signalements'),
            const BulletPoint(text: 'Like et réactions'),
            const SizedBox(height: 12),
            const Text(
              'Vous pouvez toujours consulter le contenu existant.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        actions: [
          TextButton(
            onPressed: () {
              _isShowingDialog = false;
              Navigator.pop(dialogContext);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) {
      _isShowingDialog = false;
    });
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Vérifier si l'utilisateur peut effectuer une action
  static Future<bool> canPerformAction(String action) async {
    final restricted = await isAccountRestricted();
    if (!restricted) return true;
    
    // Actions interdites pendant la restriction
    const forbiddenActions = [
      'create_post',
      'create_comment',
      'report',
      'like',
      'same_feeling',
    ];
    
    return !forbiddenActions.contains(action);
  }

  /// Afficher une erreur si l'action est interdite
  static Future<bool> checkActionAllowed(BuildContext context, String action) async {
    final allowed = await canPerformAction(action);
    if (!allowed) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action temporairement désactivée en raison d\'une restriction de compte.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
    return true;
  }

  /// Nettoyer les ressources
  static void dispose() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _isInitialized = false;
  }
}

// Widget utilitaire pour afficher des puces
class BulletPoint extends StatelessWidget {
  final String text;
  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          const Text('• ', style: TextStyle(fontSize: 12)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}