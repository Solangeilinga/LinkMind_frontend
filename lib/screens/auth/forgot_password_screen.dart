import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _identifierCtrl  = TextEditingController();
  final _otpCtrl         = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  int     _step      = 0;
  bool    _obscure1  = true;
  bool    _obscure2  = true;
  bool    _isLoading = false;
  String? _error;
  String? _hint;
  String? _resetToken;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ─── Étape 0 → 1 : envoi du code ─────────────────────────────────────────
  Future<void> _sendOtp() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Saisis ton adresse email');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _error = null; });

    try {
      final result = await ref.read(authProvider.notifier).forgotPassword(
        email: identifier,
      );

      // Vérification supplémentaire : si le résultat contient un indicateur de succès
      if (result.containsKey('success') && result['success'] == false) {
        throw Exception(result['message'] ?? 'Erreur inconnue');
      }

      if (!mounted) {
        return;
      }

      // Forcer la mise à jour UI après un court délai pour éviter les conflits de rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hint = 'Code envoyé à ton adresse email (vérifie aussi tes spams).';
            _step = 1;
          });
        } else {
        }
      });
    } catch (e) {

      if (!mounted) return;

      // Lire l'erreur depuis l'état global du provider
      final authState = ref.read(authProvider);
      final authErr = authState.error;


      setState(() {
        _isLoading = false;
        _error = authErr ?? 'Impossible d\'envoyer le code. Réessaie.';
      });
    } finally {
      // Sécurité : si pour une raison quelconque _isLoading est resté true, on le remet à false
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Étape 1 → 2 : vérification du code ──────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Le code doit faire 6 chiffres');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _error = null; });

    try {
      final identifier = _identifierCtrl.text.trim();
      final isEmail    = identifier.contains('@');

      final token = await ref.read(authProvider.notifier).verifyOtp(
        email: isEmail ? identifier : null,
        code: otp,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _resetToken = token;
        _step = 2;
      });
      debugPrint('🔑 [ForgotPwd] Passage à l’étape 2, resetToken=${_resetToken != null ? 'non null' : 'null'}');
    } catch (e) {

      if (!mounted) return;
      final authErr = ref.read(authProvider).error;
      setState(() {
        _isLoading = false;
        _error = authErr ?? 'Code incorrect ou expiré. Réessaie.';
      });
    }
  }

  // ─── Étape 2 : réinitialisation ────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (newPass.length < 6) {
      setState(() => _error = 'Le mot de passe doit faire au moins 6 caractères');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _error = null; });

    try {
      final identifier = _identifierCtrl.text.trim();
      final isEmail    = identifier.contains('@');

      await ref.read(authProvider.notifier).resetPassword(
        email: isEmail ? identifier : null,
        resetToken: _resetToken!,
        newPassword: newPass,
      );
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe réinitialisé avec succès ✅'),
          backgroundColor: AppColors.secondary,
        ),
      );
      context.go('/auth/login');
    } catch (e) {

      if (!mounted) return;
      final authErr = ref.read(authProvider).error;
      setState(() {
        _isLoading = false;
        _error = authErr ?? 'Réinitialisation échouée. Recommence depuis le début.';
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () {
  if (_step > 0) {
    setState(() { _step--; _error = null; });
  } else {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/auth/login');
    }
  }
}),
        title: Text(
          _step == 0 ? 'Récupérer mon compte'
              : _step == 1 ? 'Code de vérification'
              : 'Nouveau mot de passe',
          style: AppTextStyles.h4,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Barre de progression
            Row(children: List.generate(3, (i) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i <= _step ? AppColors.primary : AppColors.divider,
                  borderRadius: AppRadius.full,
                ),
              ),
            ))),
            const SizedBox(height: 28),

            // Erreur
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Étape 0 : saisie identifiant ──
            if (_step == 0) ...[
              const Text('Mot de passe oublié ?', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                "Saisis l'email ou le numéro avec lequel tu t'es inscrit. "
                "On t'envoie un code de vérification.",
                style: AppTextStyles.body.copyWith(
                    color: AppColors.onSurfaceMuted, height: 1.5),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _identifierCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _sendOtp(),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.person_outline),
                  helperText: '',
                ),
              ),
            ],

            // ── Étape 1 : saisie OTP ──
            if (_step == 1) ...[
              const Text('Entre ton code', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              if (_hint != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: AppRadius.md,
                  ),
                  child: Row(children: [
                    const Icon(Icons.mark_email_read_outlined,
                        color: AppColors.secondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_hint!,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.secondary))),
                  ]),
                ),
              const SizedBox(height: 24),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                autofocus: true,
                enabled: !_isLoading,
                onChanged: (val) {
                  if (val.length == 6 && !_isLoading) {
                    _verifyOtp();
                  }
                },
                style: AppTextStyles.h2.copyWith(letterSpacing: 14),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: AppTextStyles.h2.copyWith(
                      color: AppColors.onSurfaceMuted.withValues(alpha: 0.3),
                      letterSpacing: 14),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isLoading ? null : () async {
                  setState(() { _otpCtrl.clear(); _error = null; });
                  await _sendOtp();
                },
                child: Text(
                  'Renvoyer le code',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _isLoading ? AppColors.onSurfaceMuted : AppColors.primary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
            ],

            // ── Étape 2 : nouveau mot de passe ──
            if (_step == 2) ...[
              const Text('Nouveau mot de passe', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'Choisis un mot de passe sécurisé d\'au moins 6 caractères.',
                style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _newPassCtrl,
                obscureText: _obscure1,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPassCtrl,
                obscureText: _obscure2,
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _resetPassword(),
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Bouton principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () {
                  if (_step == 0) {
                    _sendOtp();
                  } else if (_step == 1) _verifyOtp();
                  else _resetPassword();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _step == 0 ? 'Envoyer le code'
                            : _step == 1 ? 'Vérifier le code'
                            : 'Réinitialiser le mot de passe',
                        style: AppTextStyles.button,
                      ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}