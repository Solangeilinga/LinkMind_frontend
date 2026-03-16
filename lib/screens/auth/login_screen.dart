import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';

// Normalise un numéro : supprime espaces, tirets, points
String _normalizePhone(String p) => p.replaceAll(RegExp(r'[\s\-\.]'), '');

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierCtrl = TextEditingController(); // email ou téléphone
  final _passCtrl       = TextEditingController();
  bool _obscurePass     = true;

  @override
  void dispose() { _identifierCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    final password   = _passCtrl.text;
    if (identifier.isEmpty || password.isEmpty) return;

    final isEmail = identifier.contains('@');
    final phone = isEmail ? null : _normalizePhone(identifier);
    final success = await ref.read(authProvider.notifier).login(
      email:    isEmail ? identifier : null,
      phone:    phone,
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

            // Logo / titre
            Center(child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: AppRadius.lg),
                child: const Center(child: Text('🧠', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 16),
              Text('LinkMind', style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
              const SizedBox(height: 4),
              Text('Connecte-toi à ton espace bien-être',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
            ])),
            const SizedBox(height: 40),

            // Erreur
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

            // Email ou téléphone
            TextField(
              controller: _identifierCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email ou téléphone (+22661645069)',
                prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),

            // Mot de passe
            TextField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                )),
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

            // Bouton connexion
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

            // Lien inscription
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
  String? _gender;
  bool    _obscurePass    = true;
  bool    _obscureConfirm = true;
  int     _step           = 0; // 0 = identité, 1 = infos perso, 2 = pseudo + mdp

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
    super.dispose();
  }

  String? _validateStep() {
    if (_step == 0) {
      if (_firstNameCtrl.text.trim().isEmpty) return 'Le prénom est obligatoire';
      if (_lastNameCtrl.text.trim().isEmpty)  return 'Le nom est obligatoire';
      if (_emailCtrl.text.trim().isEmpty && _phoneCtrl.text.trim().isEmpty)
        return 'Un email ou un numéro de téléphone est requis';
      if (_emailCtrl.text.trim().isNotEmpty && !_emailCtrl.text.contains('@'))
        return "Format d'email invalide";
    }
    if (_step == 2) {
      if (_passCtrl.text.length < 6) return 'Le mot de passe doit faire au moins 6 caractères';
      if (_passCtrl.text != _confirmCtrl.text) return 'Les mots de passe ne correspondent pas';
    }
    return null;
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
      phone:          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      age:            int.tryParse(_ageCtrl.text.trim()),
      city:           _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      gender:         _gender,
      password:       _passCtrl.text,
      anonymousAlias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
    );
    if (success && mounted) context.go('/home');
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
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Erreur globale
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

            // ── Étape 0 : Identité ──
            if (_step == 0) ...[
              Text('Qui es-tu ?', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('Tes infos de base pour créer ton compte',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 24),

              Row(children: [
                Expanded(child: TextField(
                  controller: _firstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    prefixIcon: Icon(Icons.person_outline)))),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _lastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom *'))),
              ]),
              const SizedBox(height: 16),

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optionnel)',
                  prefixIcon: Icon(Icons.email_outlined),
                  helperText: 'Pour récupérer ton compte'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone (optionnel)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  helperText: 'Format international: +22661645069'),
              ),
              const SizedBox(height: 8),
              Text('* Au moins un email ou un numéro est requis',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.onSurfaceMuted, fontStyle: FontStyle.italic)),
            ],

            // ── Étape 1 : Infos personnelles ──
            if (_step == 1) ...[
              Text('À propos de toi', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('Ces infos restent privées et t\'aident à personnaliser l\'expérience',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 24),

              // Age
              TextField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Âge (optionnel)',
                  prefixIcon: Icon(Icons.cake_outlined),
                  hintText: 'Ex: 20'),
              ),
              const SizedBox(height: 20),

              // Ville
              TextField(
                controller: _cityCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ville (optionnel)',
                  prefixIcon: Icon(Icons.location_city_outlined)),
              ),
              const SizedBox(height: 20),

              // Genre
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

            // ── Étape 2 : Pseudo + Mot de passe ──
            if (_step == 2) ...[
              Text('Sécurise ton compte', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('Choisis ton pseudo communauté et ton mot de passe',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
              const SizedBox(height: 24),

              // Pseudo anonyme
              TextField(
                controller: _aliasCtrl,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: '🎭 Pseudo anonyme (optionnel)',
                  hintText: 'Ex: 🌙 Lune curieuse',
                  prefixIcon: const Icon(Icons.face_outlined),
                  counterStyle: AppTextStyles.caption
                      .copyWith(color: AppColors.onSurfaceMuted)),
              ),
              const SizedBox(height: 16),

              // Mot de passe
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
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

              // Confirmer
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))),
              ),
            ],

            const SizedBox(height: 32),

            // Bouton
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : () {
                  final error = _validateStep();
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error), backgroundColor: AppColors.accent));
                    return;
                  }
                  if (_step < 2) {
                    setState(() => _step++);
                  } else {
                    _register();
                  }
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