import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../services/api.service.dart';

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passCtrl       = TextEditingController();
  bool _obscurePass     = true;

  @override
  void dispose() { _identifierCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    final password   = _passCtrl.text;
    if (identifier.isEmpty || password.isEmpty) return;
    final isEmail = identifier.contains('@');
    final phone = isEmail ? null : Validators.normalizePhone(identifier);
    final success = await ref.read(authProvider.notifier).login(
      email: isEmail ? identifier : null,
      phone: phone,
      password: password,
    );
    if (success && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 40),
            Center(child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.lg),
                child: ClipRRect(
                  borderRadius: AppRadius.lg,
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
              ),
              const SizedBox(height: 16),
              Text('LinkMind', style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
              const SizedBox(height: 4),
              Text('Connecte-toi à ton espace bien-être',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
            ])),
            const SizedBox(height: 40),

            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent))),
                ]),
              ),

            TextField(
              controller: _identifierCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email ou téléphone (+22661645069)',
                prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass))),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => context.go('/auth/forgot-password'),
                child: Text('Mot de passe oublié ?',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _login,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: state.isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Se connecter'),
              ),
            ),
            const SizedBox(height: 20),

            Center(child: GestureDetector(
              onTap: () => context.go('/auth/register'),
              child: RichText(text: TextSpan(
                style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                children: [
                  const TextSpan(text: "Pas encore de compte ? "),
                  TextSpan(text: "Créer un compte",
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w800)),
                ],
              )),
            )),
          ]),
        ),
      ),
    );
  }
}

// ─── Register Screen ──────────────────────────────────────────────────────────
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _aliasCtrl     = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _ageCtrl       = TextEditingController();

  final _aliasFocus   = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  String? _emailError;
  String? _phoneError;
  String? _ageError;

  String? _gender;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  int  _step           = 0;

  final _scrollCtrl = ScrollController();

  static const _genders = [
    ('homme',        '👨 Homme'),
    ('femme',        '👩 Femme'),
    ('non_specifie', '— Préfère ne pas préciser'),
  ];

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _emailCtrl.dispose();     _phoneCtrl.dispose();
    _passCtrl.dispose();      _confirmCtrl.dispose();
    _aliasCtrl.dispose();     _cityCtrl.dispose();
    _ageCtrl.dispose();
    _aliasFocus.dispose();    _passFocus.dispose();
    _confirmFocus.dispose();  _scrollCtrl.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final v = _emailCtrl.text.trim();
    setState(() {
      if (v.isEmpty) { _emailError = null; return; }
      _emailError = Validators.isValidEmail(v) ? null : "Format d'email invalide";
    });
  }

  void _validatePhone() {
    final v = Validators.normalizePhone(_phoneCtrl.text.trim());
    setState(() {
      if (v.isEmpty) { _phoneError = null; return; }
      _phoneError = Validators.isValidPhone(v) ? null : 'Format invalide. Ex: +22661645069';
    });
  }

  void _validateAge() {
    final v = _ageCtrl.text.trim();
    setState(() {
      if (v.isEmpty) { _ageError = null; return; }
      _ageError = Validators.isValidAge(v) ? null : "L'âge doit être entre 15 et 120 ans";
    });
  }

  String? _validateStep() {
    if (_step == 0) {
      if (_firstNameCtrl.text.trim().isEmpty) return 'Le prénom est obligatoire';
      if (_lastNameCtrl.text.trim().isEmpty)  return 'Le nom est obligatoire';
      
      final emailTxt = _emailCtrl.text.trim();
      final phoneTxt = _phoneCtrl.text.trim();
      
      if (emailTxt.isEmpty && phoneTxt.isEmpty) {
        return 'Un email ou un numéro de téléphone est requis';
      }
      
      // ✅ Validation en temps réel du texte des contrôleurs
      if (emailTxt.isNotEmpty && !Validators.isValidEmail(emailTxt)) {
        return "Format d'email invalide";
      }
      if (phoneTxt.isNotEmpty && !Validators.isValidPhone(Validators.normalizePhone(phoneTxt))) {
        return "Format de téléphone invalide. Ex: +22661645069";
      }
    }
    if (_step == 1) {
      final ageTxt = _ageCtrl.text.trim();
      // ✅ Validation en temps réel de l'âge
      if (ageTxt.isNotEmpty && !Validators.isValidAge(ageTxt)) {
        return "L'âge doit être entre 15 et 120 ans";
      }
    }
    if (_step == 2) {
      if (!Validators.isValidPassword(_passCtrl.text)) return 'Le mot de passe doit faire au moins 6 caractères';
      if (_passCtrl.text != _confirmCtrl.text) return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  void _nextStep() {
    final error = _validateStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.accent));
      return;
    }
    setState(() => _step++);

    if (_step == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _aliasFocus.requestFocus();
        });
      });
    }
  }

  Future<void> _register() async {
    final error = _validateStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.accent));
      return;
    }
    final success = await ref.read(authProvider.notifier).register(
      firstName:      _firstNameCtrl.text.trim(),
      lastName:       _lastNameCtrl.text.trim(),
      email:          _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone:          _phoneCtrl.text.trim().isEmpty ? null : Validators.normalizePhone(_phoneCtrl.text.trim()),
      age:            int.tryParse(_ageCtrl.text.trim()),
      city:           _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      gender:         _gender,
      password:       _passCtrl.text,
      anonymousAlias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
    );
    
    if (success && mounted) {
      final user = ref.read(authProvider).user;
      debugPrint('🔍 User après inscription: email=${user?.email}, isEmailVerified=${user?.isEmailVerified}');
      
      // ✅ Si l'utilisateur a un email et n'est pas vérifié
      if (user?.email != null && user?.isEmailVerified != true) {
        debugPrint('📧 Envoi du code de vérification...');
        try {
          await ApiService().sendVerification();
          debugPrint('📧 Redirection vers /verify-email');
          if (mounted) {
            context.go('/verify-email');
          }
        } catch (e) {
          debugPrint('❌ Erreur envoi code: $e');
          if (mounted) {
            context.go('/legal-onboarding');
          }
        }
      } else {
        // Pas d'email ou déjà vérifié
        debugPrint('➡️ Pas d\'email ou déjà vérifié, redirection vers legal-onboarding');
        if (mounted) {
          context.go('/legal-onboarding');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () {
          if (_step > 0) setState(() => _step--);
          else context.pop();
        }),
        title: Text('Étape ${_step + 1} / 3', style: AppTextStyles.bodySmall),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: AppColors.divider,
            color: AppColors.primary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                width: 60, height: 60,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.md),
                child: ClipRRect(
                  borderRadius: AppRadius.md,
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
              ),
            ),

            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent))),
                ]),
              ),

            // ── Étape 0 : Identité ──────────────────────────────────────────
            if (_step == 0) ...[
              Text('Qui es-tu ?', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text("Tes infos de base pour créer ton compte",
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 24),

              Row(children: [
                Expanded(child: TextField(
                  controller: _firstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    prefixIcon: Icon(Icons.person_outline)))),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _lastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nom *'))),
              ]),
              const SizedBox(height: 16),

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onEditingComplete: _validateEmail,
                decoration: InputDecoration(
                  labelText: 'Email (optionnel)',
                  prefixIcon: const Icon(Icons.email_outlined),
                  helperText: _emailError == null ? 'Pour récupérer ton compte' : null,
                  errorText: _emailError,
                  suffixIcon: _emailCtrl.text.isNotEmpty
                      ? Icon(_emailError == null ? Icons.check_circle : Icons.error,
                          color: _emailError == null ? Colors.green : AppColors.accent,
                          size: 18)
                      : null),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onEditingComplete: _validatePhone,
                onChanged: (_) {
                  if (_phoneCtrl.text.length >= 6) _validatePhone();
                },
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone (optionnel)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  helperText: _phoneError == null ? 'Format international: +22661645069' : null,
                  errorText: _phoneError,
                  suffixIcon: _phoneCtrl.text.isNotEmpty
                      ? Icon(_phoneError == null ? Icons.check_circle : Icons.error,
                          color: _phoneError == null ? Colors.green : AppColors.accent,
                          size: 18)
                      : null),
              ),
              const SizedBox(height: 8),
              Text('* Au moins un email ou un numéro est requis',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.onSurfaceMuted, fontStyle: FontStyle.italic)),
            ],

            // ── Étape 1 : Infos personnelles ────────────────────────────────
            if (_step == 1) ...[
              Text('À propos de toi', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text("Ces infos restent privées et t'aident à personnaliser l'expérience",
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 24),

              TextField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onEditingComplete: _validateAge,
                onChanged: (_) { if (_ageCtrl.text.length >= 1) _validateAge(); },
                decoration: InputDecoration(
                  labelText: 'Âge (optionnel)',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  hintText: 'Ex: 20',
                  errorText: _ageError,
                  helperText: _ageError == null && _ageCtrl.text.isNotEmpty ? 'Valide ✓' : null,
                  helperStyle: const TextStyle(color: Colors.green),
                  suffixIcon: _ageCtrl.text.isNotEmpty
                      ? Icon(_ageError == null ? Icons.check_circle : Icons.error,
                          color: _ageError == null ? Colors.green : AppColors.accent,
                          size: 18)
                      : null),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _cityCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Ville (optionnel)',
                  prefixIcon: Icon(Icons.location_city_outlined)),
              ),
              const SizedBox(height: 20),

              Text('Genre (optionnel)',
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...(_genders.map((g) => RadioListTile<String>(
                value: g.$1,
                groupValue: _gender,
                onChanged: (v) => setState(() => _gender = _gender == v ? null : v),
                title: Text(g.$2, style: AppTextStyles.body),
                dense: true,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ))).toList(),
            ],

            // ── Étape 2 : Pseudo + Mot de passe ─────────────────────────────
            if (_step == 2) ...[
              Text('Sécurise ton compte', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('Choisis ton pseudo communauté et ton mot de passe',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
                child: Row(children: [
                  const Text('🎭', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    "Ce pseudo sera ton identité dans la communauté.",
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary, height: 1.4),
                  )),
                ]),
              ),

              TextField(
                controller: _aliasCtrl,
                focusNode: _aliasFocus,
                maxLength: 30,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _passFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: '🎭 Pseudo anonyme (optionnel)',
                  hintText: 'Ex: 🌙 Lune curieuse',
                  prefixIcon: const Icon(Icons.face_outlined),
                  counterStyle: AppTextStyles.caption
                      .copyWith(color: AppColors.onSurfaceMuted)),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _passCtrl,
                focusNode: _passFocus,
                obscureText: _obscurePass,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _confirmFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: 'Mot de passe (min. 6 caractères)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass))),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _confirmCtrl,
                focusNode: _confirmFocus,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _register(),
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: _confirmCtrl.text.isNotEmpty
                      ? Icon(
                          _passCtrl.text == _confirmCtrl.text
                              ? Icons.check_circle
                              : Icons.error,
                          color: _passCtrl.text == _confirmCtrl.text
                              ? Colors.green
                              : AppColors.accent,
                          size: 18)
                      : IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm))),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : () {
                  if (_step < 2) _nextStep();
                  else _register();
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: state.isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_step < 2 ? 'Continuer →' : 'Créer mon compte'),
              ),
            ),

            if (_step == 0) ...[
              const SizedBox(height: 20),
              Center(child: GestureDetector(
                onTap: () => context.go('/auth/login'),
                child: RichText(text: TextSpan(
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                  children: [
                    const TextSpan(text: "Déjà un compte ? "),
                    TextSpan(text: "Se connecter",
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ],
                )),
              )),
            ],
          ]),
        ),
      ),
    );
  }
}