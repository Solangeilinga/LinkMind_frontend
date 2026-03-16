import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../services/api.service.dart';


// Normalise un numéro : supprime espaces, tirets, points
String _normalizePhone(String p) => p.replaceAll(RegExp(r'[\s\-\.]'), '');
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
  bool    _loading    = false;
  bool    _obscure1   = true;
  bool    _obscure2   = true;
  String? _error;
  String? _hint;       // ex: "Code envoyé à ab***@gmail.com"
  String? _resetToken; // token temporaire après OTP vérifié

  @override
  void dispose() {
    _identifierCtrl.dispose(); _otpCtrl.dispose();
    _newPassCtrl.dispose();    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // Étape 0 → envoie OTP
  Future<void> _sendOtp() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Saisis ton email ou ton numéro de téléphone');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final isEmail = identifier.contains('@');
      final phone = isEmail ? null : _normalizePhone(identifier);
      final data = await ApiService().post('/auth/forgot-password', {
        if (isEmail) 'email': identifier,
        if (!isEmail) 'phone': phone!,
      });
      setState(() {
        _loading = false;
        _hint    = data['hint'] as String?;
        _step    = 1;
      });
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Une erreur est survenue'; });
    }
  }

  // Étape 1 → vérifie OTP
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Le code fait 6 chiffres');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final identifier = _identifierCtrl.text.trim();
      final isEmail = identifier.contains('@');
      final data = await ApiService().post('/auth/verify-otp', {
        if (isEmail) 'email': identifier,
        if (!isEmail) 'phone': identifier,
        'code': otp,
      });
      setState(() {
        _loading    = false;
        _resetToken = data['resetToken'] as String?;
        _step       = 2;
      });
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Une erreur est survenue'; });
    }
  }

  // Étape 2 → reset mot de passe
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
    setState(() { _loading = true; _error = null; });
    try {
      final identifier = _identifierCtrl.text.trim();
      final isEmail = identifier.contains('@');
      await ApiService().post('/auth/reset-password', {
        if (isEmail) 'email': identifier,
        if (!isEmail) 'phone': identifier,
        'resetToken':  _resetToken,
        'newPassword': newPass,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe réinitialisé ✅'),
              backgroundColor: AppColors.secondary));
        context.go('/auth/login');
      }
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Une erreur est survenue'; });
    }
  }

  @override
  Widget build(BuildContext context) {
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

            // Indicateur d'étape
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

            // Erreur
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Étape 0 : Identifiant ──
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

            // ── Étape 1 : Code OTP ──
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
                onTap: _loading ? null : () {
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

            // ── Étape 2 : Nouveau mot de passe ──
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
                onPressed: _loading ? null : () {
                  if (_step == 0) _sendOtp();
                  else if (_step == 1) _verifyOtp();
                  else _resetPassword();
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: _loading
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