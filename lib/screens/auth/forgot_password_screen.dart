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
    debugPrint('🔑 [ForgotPwd] _sendOtp called, identifier="$identifier"');
    if (identifier.isEmpty) {
      setState(() => _error = 'Saisis ton email ou ton numéro de téléphone');
      debugPrint('❌ [ForgotPwd] Champ vide');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _error = null; });
    debugPrint('🔑 [ForgotPwd] isLoading=true, calling forgotPassword...');

    final isEmail = identifier.contains('@');
    final phone   = isEmail ? null : Validators.normalizePhone(identifier);
    debugPrint('🔑 [ForgotPwd] isEmail=$isEmail, phone=$phone');

    try {
      // Appel au notifier
      final result = await ref.read(authProvider.notifier).forgotPassword(
        email: isEmail ? identifier : null,
        phone: phone,
      );
      debugPrint('✅ [ForgotPwd] forgotPassword terminé, résultat brut = $result');

      // Vérification supplémentaire : si le résultat contient un indicateur de succès
      if (result.containsKey('success') && result['success'] == false) {
        throw Exception(result['message'] ?? 'Erreur inconnue');
      }

      debugPrint('🔑 [ForgotPwd] Appel réussi, mounted = $mounted');

      if (!mounted) {
        debugPrint('⚠️ [ForgotPwd] Widget démonté avant mise à jour UI');
        return;
      }

      // Forcer la mise à jour UI après un court délai pour éviter les conflits de rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('🔑 [ForgotPwd] Mise à jour UI (step=1) depuis postFrameCallback');
          setState(() {
            _isLoading = false;
            _hint = isEmail
                ? 'Code envoyé à ton adresse email (vérifie aussi tes spams).'
                : 'Code envoyé par SMS à ton numéro.';
            _step = 1;
          });
          debugPrint('🔑 [ForgotPwd] Nouvel état : step=$_step, isLoading=$_isLoading');
        } else {
          debugPrint('⚠️ [ForgotPwd] Widget non mounted dans postFrameCallback');
        }
      });
    } catch (e, stack) {
      debugPrint('❌ [ForgotPwd] Exception dans _sendOtp : ${e.runtimeType} : $e');
      debugPrint('📚 Stack trace : $stack');
      if (!mounted) return;

      // Lire l'erreur depuis l'état global du provider
      final authState = ref.read(authProvider);
      final authErr = authState.error;
      debugPrint('❌ [ForgotPwd] authState.error = $authErr');
      debugPrint('❌ [ForgotPwd] authState.isLoading = ${authState.isLoading}');

      setState(() {
        _isLoading = false;
        _error = authErr ?? 'Impossible d\'envoyer le code. Réessaie.';
      });
      debugPrint('❌ [ForgotPwd] Erreur affichée : $_error');
    } finally {
      // Sécurité : si pour une raison quelconque _isLoading est resté true, on le remet à false
      if (mounted && _isLoading) {
        debugPrint('⚠️ [ForgotPwd] finally: reset _isLoading à false');
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Étape 1 → 2 : vérification du code ──────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    debugPrint('🔑 [ForgotPwd] _verifyOtp called, otp="$otp", length=${otp.length}');
    if (otp.length != 6) {
      setState(() => _error = 'Le code doit faire 6 chiffres');
      debugPrint('❌ [ForgotPwd] Code invalide (longueur ${otp.length})');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _error = null; });
    debugPrint('🔑 [ForgotPwd] verifyOtp: appel API...');

    try {
      final identifier = _identifierCtrl.text.trim();
      final isEmail    = identifier.contains('@');
      final phone      = isEmail ? null : Validators.normalizePhone(identifier);
      debugPrint('🔑 [ForgotPwd] verifyOtp paramètres : email=$identifier, phone=$phone, code=$otp');

      final token = await ref.read(authProvider.notifier).verifyOtp(
        email: isEmail ? identifier : null,
        phone: phone,
        code: otp,
      );

      debugPrint('✅ [ForgotPwd] verifyOtp réussi, resetToken = $token, mounted=$mounted');

      if (!mounted) {
        debugPrint('⚠️ [ForgotPwd] Widget démonté après vérification');
        return;
      }

      setState(() {
        _isLoading = false;
        _resetToken = token;
        _step = 2;
      });
      debugPrint('🔑 [ForgotPwd] Passage à l’étape 2, resetToken=${_resetToken != null ? 'non null' : 'null'}');
    } catch (e, stack) {
      debugPrint('❌ [ForgotPwd] _verifyOtp error: ${e.runtimeType}: $e');
      debugPrint('📚 Stack : $stack');
      if (!mounted) return;
      final authErr = ref.read(authProvider).error;
      debugPrint('❌ [ForgotPwd] authErr = $authErr');
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
    debugPrint('🔑 [ForgotPwd] _resetPassword, newPass length=${newPass.length}');

    if (newPass.length < 6) {
      setState(() => _error = 'Le mot de passe doit faire au moins 6 caractères');
      debugPrint('❌ [ForgotPwd] Mot de passe trop court');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      debugPrint('❌ [ForgotPwd] Mots de passe différents');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _error = null; });
    debugPrint('🔑 [ForgotPwd] Appel resetPassword...');

    try {
      final identifier = _identifierCtrl.text.trim();
      final isEmail    = identifier.contains('@');
      final phone      = isEmail ? null : Validators.normalizePhone(identifier);
      debugPrint('🔑 [ForgotPwd] resetPassword params : email=$identifier, phone=$phone, token présent=${_resetToken != null}');

      await ref.read(authProvider.notifier).resetPassword(
        email: isEmail ? identifier : null,
        phone: phone,
        resetToken: _resetToken!,
        newPassword: newPass,
      );

      debugPrint('✅ [ForgotPwd] resetPassword réussi, mounted=$mounted');
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe réinitialisé avec succès ✅'),
          backgroundColor: AppColors.secondary,
        ),
      );
      debugPrint('🔑 [ForgotPwd] Navigation vers /auth/login');
      context.go('/auth/login');
    } catch (e, stack) {
      debugPrint('❌ [ForgotPwd] resetPassword error: ${e.runtimeType}: $e');
      debugPrint('📚 Stack : $stack');
      if (!mounted) return;
      final authErr = ref.read(authProvider).error;
      debugPrint('❌ [ForgotPwd] authErr = $authErr');
      setState(() {
        _isLoading = false;
        _error = authErr ?? 'Réinitialisation échouée. Recommence depuis le début.';
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 [ForgotPwd] build() appelée, step=$_step, isLoading=$_isLoading');
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () {
  if (_step > 0) {
    debugPrint('🔙 [ForgotPwd] Retour à l’étape ${_step - 1}');
    setState(() { _step--; _error = null; });
  } else {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      debugPrint('🔙 [ForgotPwd] Rien à pop, retour vers /auth/login');
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
              Text('Mot de passe oublié ?', style: AppTextStyles.h2),
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
                  labelText: 'Email ou numéro de téléphone',
                  prefixIcon: Icon(Icons.person_outline),
                  helperText: 'Format téléphone : +22661645069',
                ),
              ),
            ],

            // ── Étape 1 : saisie OTP ──
            if (_step == 1) ...[
              Text('Entre ton code', style: AppTextStyles.h2),
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
                    debugPrint('🔑 [ForgotPwd] Code complet automatique, déclenche _verifyOtp');
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
                  debugPrint('🔁 [ForgotPwd] Renvoi du code demandé');
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
              Text('Nouveau mot de passe', style: AppTextStyles.h2),
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
                  debugPrint('🔘 [ForgotPwd] Bouton principal pressé, step=$_step');
                  if (_step == 0) _sendOtp();
                  else if (_step == 1) _verifyOtp();
                  else _resetPassword();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
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