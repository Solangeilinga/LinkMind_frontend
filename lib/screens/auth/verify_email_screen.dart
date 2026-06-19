import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  String? _success;
  String? _channel;
  String? _destinationMasked;

  @override
  void initState() {
    super.initState();
    // Le code a déjà été envoyé lors de l'inscription
    // On initialise juste le channel à 'email' sans rappel API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _channel = 'email';
          _destinationMasked = null;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendInitialCode() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(authProvider.notifier).sendVerification();
      if (mounted) {
        setState(() {
          _channel = response['channel'];
          _destinationMasked = response['destination'];
          _isLoading = false;
        });
        debugPrint(
            '✅ Code envoyé par ${response['channel'] == 'email' ? 'email' : 'SMS'}');
      }
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Timeout lors de l\'envoi du code: $e');
      if (mounted) {
        setState(() {
          _error =
              'Délai d\'attente dépassé. Vérifiez votre connexion et réessayez.';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ Erreur _sendInitialCode: $e\n$stack');
      if (mounted) {
        // Message d'erreur plus spécifique selon le type d'erreur
        String errorMsg = 'Impossible d\'envoyer le code de vérification';
        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('429') || errorStr.contains('rate')) {
          errorMsg =
              'Trop de tentatives. Attends 2 minutes avant de réessayer.';
        } else if (errorStr.contains('timeout')) {
          errorMsg = 'Délai d\'attente dépassé. Réessaie.';
        } else if (errorStr.contains('configuration') ||
            errorStr.contains('credentials')) {
          errorMsg = 'Service SMS non configuré. Contacte le support.';
        } else if (errorStr.contains('lafricamobile') ||
            errorStr.contains('sms')) {
          errorMsg = 'Problème d\'envoi SMS. Réessaie ou utilise un email.';
        } else if (errorStr.contains('not properly configured')) {
          errorMsg = 'Service non disponible. Réessaie plus tard.';
        }
        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() => _error = 'Code à 6 chiffres requis');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final verified = await ref.read(authProvider.notifier).verifyEmail(code);
      debugPrint('✅ verifyEmail retourné: $verified');

      if (verified && mounted) {
        // Redirection vers l'onboarding classique (le routeur gère la suite)
        context.go('/onboarding');
      } else {
        if (mounted) setState(() => _error = 'Code invalide');
      }
    } catch (e, stack) {
      debugPrint('❌ Erreur _verifyCode: $e\n$stack');
      if (mounted) {
        setState(() =>
            _error = 'Erreur lors de la vérification. Réessaie plus tard.');
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _error = null;
      _success = null;
    });

    try {
      final response = await ref.read(authProvider.notifier).sendVerification();
      if (mounted) {
        setState(() {
          _success =
              'Nouveau code envoyé par ${response['channel'] == 'email' ? 'email' : 'SMS'}';
          _isResending = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Erreur _resendCode: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = 'Erreur, réessaie plus tard';
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _channel == null) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final icon = _channel == 'email' ? '📧' : '📱';
    final title =
        _channel == 'email' ? 'Vérifie ton email' : 'Vérifie ton téléphone';
    final subtitle = _channel == 'email'
        ? 'Un code de vérification a été envoyé à ton adresse email lors de ton inscription'
        : 'Un code de vérification a été envoyé par SMS à ton numéro lors de ton inscription';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vérification'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Text(icon, style: const TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.onSurfaceMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (_destinationMasked != null)
                Text(
                  _destinationMasked!,
                  style: AppTextStyles.h4.copyWith(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!, style: AppTextStyles.bodySmall)),
                    ],
                  ),
                ),
              if (_success != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                          child:
                              Text(_success!, style: AppTextStyles.bodySmall)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                onChanged: (val) {
                  if (val.length == 6) {
                    _verifyCode();
                  }
                },
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Vérifier'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Tu n\'as pas reçu le code ?',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.onSurfaceMuted),
                  ),
                  TextButton(
                    onPressed: _isResending ? null : _resendCode,
                    child: _isResending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Renvoyer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}