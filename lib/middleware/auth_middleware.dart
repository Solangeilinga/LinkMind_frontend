import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api.service.dart';

/// Middleware pour gérer les erreurs d'authentification
class AuthMiddleware {
  static Future<bool> handleUnauthorized(BuildContext context) async {
    // Vérifier si le token existe
    final token = await ApiService().getAccessToken();
    if (token == null) {
      _redirectToLogin(context);
      return false;
    }

    // Essayer de rafraîchir le token
    try {
      final refreshed = await ApiService().refreshAccessToken();
      if (!refreshed) {
        _redirectToLogin(context);
        return false;
      }
      return true;
    } catch (e) {
      _redirectToLogin(context);
      return false;
    }
  }

  static void _redirectToLogin(BuildContext context) {
    if (context.mounted) {
      // ✅ CORRECTION : La route définie dans main.dart est /auth/login
      context.go('/auth/login'); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expirée, veuillez vous reconnecter'),
          backgroundColor: Colors.orange, // Ou AppColors.accentOrange
        ),
      );
    }
  }

  /// Vérifier si l'utilisateur est authentifié avant d'accéder à une route
  static Future<bool> checkAuth(BuildContext context) async {
    final token = await ApiService().getAccessToken();
    if (token == null) {
      _redirectToLogin(context);
      return false;
    }
    return true;
  }
}