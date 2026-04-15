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

  int     _step       = 0; // 0=saisie identifiant, 1=saisie OTP, 2=nouveau mdp
  bool    _obscure1   = true;
  bool    _obscure2   = true;
  String? _error;
  String? _hint;
  String? _resetToken;

  @override
  void dispose() {
    _identifierCtrl.dispose(); _otpCtrl.dispose();
    _newPassCtrl.dispose();    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Saisis ton email ou ton numéro de téléphone');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    
    try {
      final isEmail = identifier.contains('@');
      final phone = isEmail ? null : Validators.normalizePhone(identifier);
      
      final data = await ref.read(authProvider.notifier).forgotPassword(
        email: isEmail ? identifier : null,
        phone: phone,
      );
      
      setState(() {
        _hint = data['hint'] as String?;
        _step = 1;
      });
    } catch (_) {
      // L'erreur est déjà gérée et stockée dans l'état du provider
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Le code fait 6 chiffres');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    
    try {
      final identifier = _identifierCtrl.text.trim();
      final isEmail = identifier.contains('@');
      final phone = isEmail ? null : Validators.normalizePhone(identifier);

      final token = await ref.read(authProvider.notifier).verifyOtp(
        email: isEmail ? identifier : null,
        phone: phone,
        code: otp,
      );
      
      setState(() {
        _resetToken = token;
        _step = 2;
      });
    } catch (_) {}
  }

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
    setState(() => _error = null);
    
    try {
      final identifier = _identifierCtrl.text.trim();
      final isEmail = identifier.contains('@');
      final phone = isEmail ? null : Validators.normalizePhone(identifier);

      await ref.read(authProvider.notifier).resetPassword(
        email: isEmail ? identifier : null,
        phone: phone,
        resetToken: _resetToken!,
        newPassword: newPass,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe réinitialisé ✅'),
              backgroundColor: AppColors.secondary));
        context.go('/auth/login');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final displayError = _error ?? authState.error; // Priorité à l'erreur locale, puis globale
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () {
          if (_step > 0) setState(() { _step--; _error = null; });
          else context.pop();
        }),
        title: Text(
          _step == 0 ? 'Récupérer mon compte'
          : _step == 1 ? 'Vérification'
          : 'Nouveau mot de passe',
          style: AppTextStyles.h4),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(children: List.generate(3, (i) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i <= _step ? AppColors.primary : AppColors.divider,
                  borderRadius: AppRadius.full),
              ),
            ))),
            const SizedBox(height: 28),

            if (displayError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(displayError,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Étape 0 ──
            if (_step == 0) ...[
              Text('Mot de passe oublié ?', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text("Saisis l'email ou le numéro avec lequel tu t'es inscrit.\nNous t'enverrons un code de vérification.",
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.onSurfaceMuted, height: 1.5)),
              const SizedBox(height: 28),
              TextField(
                controller: _identifierCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email ou numéro de téléphone',
                  prefixIcon: Icon(Icons.person_outline),
                  helperText: 'Format téléphone international: +22661645069'),
              ),
            ],

            // ── Étape 1 (AVEC AUTO-SUBMIT) ──
            if (_step == 1) ...[
              Text('Entre ton code', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              if (_hint != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: AppRadius.md),
                  child: Row(children: [
                    const Icon(Icons.send_outlined, color: AppColors.secondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_hint!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary))),
                  ]),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                onChanged: (val) {
                  // ✅ Auto-submit quand 6 chiffres sont entrés
                  if (val.length == 6) {
                    _verifyOtp();
                  }
                },
                style: AppTextStyles.h2.copyWith(letterSpacing: 12),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: AppTextStyles.h2.copyWith(
                      color: AppColors.onSurfaceMuted.withValues(alpha: 0.3),
                      letterSpacing: 12),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: isLoading ? null : () {
                  setState(() { _step = 0; _otpCtrl.clear(); _error = null; });
                },
                child: Text("Renvoyer le code",
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary)),
              ),
            ],

            // ── Étape 2 ──
            if (_step == 2) ...[
              Text('Nouveau mot de passe', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text('Choisis un mot de passe sécurisé d\'au moins 6 caractères.',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 28),
              TextField(
                controller: _newPassCtrl,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure1 = !_obscure1))),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPassCtrl,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure2 = !_obscure2))),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : () {
                  if (_step == 0) _sendOtp();
                  else if (_step == 1) _verifyOtp();
                  else _resetPassword();
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_step == 0 ? 'Envoyer le code'
                           : _step == 1 ? 'Vérifier le code'
                           : 'Réinitialiser le mot de passe'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}