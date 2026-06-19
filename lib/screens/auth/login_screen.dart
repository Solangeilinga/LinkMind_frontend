import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api.service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  String? _localError;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    final password   = _passCtrl.text;
    if (identifier.isEmpty) { setState(() => _localError = 'Saisis ton adresse email.'); return; }
    if (password.isEmpty)   { setState(() => _localError = 'Saisis ton mot de passe.'); return; }
    setState(() => _localError = null);
    final success = await ref.read(authProvider.notifier).login(
      email: identifier.contains('@') ? identifier : null,
      password: password,
    );
    if (success && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor  = isDark ? Colors.white12 : AppColors.divider;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Logo + titre ────────────────────────────────────────────
            Center(child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.lg),
                child: ClipRRect(borderRadius: AppRadius.lg,
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
              ),
              const SizedBox(height: 14),
              Text('LinkMind', style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
              const SizedBox(height: 4),
              Text('Connecte-toi à ton espace bien-être',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
            ])),
            const SizedBox(height: 32),

            // ── Erreurs ─────────────────────────────────────────────────
            if (_localError != null) ...[
              _ErrorBanner(message: _localError!, isNetwork: false),
              const SizedBox(height: 12),
            ],
            if (state.error != null) ...[
              _ErrorBanner(message: state.error!, isNetwork: state.error!.contains('internet')),
              const SizedBox(height: 12),
            ],

            // ── Card formulaire ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Adresse email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      splashRadius: 20,
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    ),
                  ),
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
              ]),
            ),
            const SizedBox(height: 20),

            // ── Bouton ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: state.isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Se connecter',
                        style: AppTextStyles.button.copyWith(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),

            // ── Lien inscription ─────────────────────────────────────────
            Center(child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted),
                children: [
                  const TextSpan(text: 'Pas encore de compte ? '),
                  TextSpan(
                    text: 'Créer un compte',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w800),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.go('/auth/register'),
                  ),
                ],
              ),
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
  final _emailCtrl   = TextEditingController();
  final _aliasCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _ageCtrl     = TextEditingController();
  final _cityCtrl    = TextEditingController();

  final _aliasFocus   = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();
  final _ageFocus     = FocusNode();
  final _cityFocus    = FocusNode();
  final _scrollCtrl   = ScrollController();

  String? _emailError;
  String? _ageError;
  String? _selectedCountry;
  String? _gender;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _legalAccepted  = false;
  int  _step           = 0;

  List<String> _countries     = [];
  bool _loadingCountries = false;

  static const _genders = [
    ('homme',        '👨  Homme'),
    ('femme',        '👩  Femme'),
    ('non_specifie', '—  Préfère ne pas préciser'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() => _loadingCountries = true);
    try {
      final res = await http
          .get(Uri.parse('https://restcountries.com/v3.1/all?fields=name,translations'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final names = data.map<String>((c) {
          final fra = c['translations']?['fra']?['common'];
          final eng = c['name']?['common'];
          return (fra ?? eng ?? '').toString();
        }).where((n) => n.isNotEmpty).toList()..sort();
        setState(() { _countries = names; _loadingCountries = false; });
      }
    } catch (_) {
      setState(() {
        _countries = [
          'Algérie','Bénin','Burkina Faso','Cameroun','Canada',
          'Côte d\'Ivoire','Égypte','États-Unis','France','Ghana',
          'Guinée','Kenya','Mali','Maroc','Mauritanie','Niger',
          'Nigeria','République démocratique du Congo','Sénégal',
          'Suisse','Belgique','Togo','Tunisie','Afrique du Sud',
        ]..sort();
        _loadingCountries = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_emailCtrl, _aliasCtrl, _passCtrl, _confirmCtrl, _ageCtrl, _cityCtrl]) c.dispose();
    for (final f in [_aliasFocus, _passFocus, _confirmFocus, _ageFocus, _cityFocus]) f.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final v = _emailCtrl.text.trim();
    setState(() => _emailError = v.isEmpty ? null : (Validators.isValidEmail(v) ? null : "Format d'email invalide"));
  }

  void _validateAge() {
    final v = _ageCtrl.text.trim();
    setState(() => _ageError = v.isEmpty ? null : (Validators.isValidAge(v) ? null : "L'âge doit être entre 13 et 120 ans"));
  }

  String? _validateStep() {
    if (_step == 0) {
      final email = _emailCtrl.text.trim();
      if (email.isEmpty) return 'L\'email est obligatoire';
      if (!Validators.isValidEmail(email)) return "Format d'email invalide";
      if (!Validators.isValidPassword(_passCtrl.text)) return 'Mot de passe trop court (min. 6 caractères)';
      if (_passCtrl.text != _confirmCtrl.text) return 'Les mots de passe ne correspondent pas';
      if (!_legalAccepted) return 'Accepte les conditions générales pour continuer';
    }
    if (_step == 1) {
      if (_ageCtrl.text.trim().isEmpty) return 'L\'âge est obligatoire';
      if (!Validators.isValidAge(_ageCtrl.text.trim())) return "L'âge doit être entre 13 et 120 ans";
      if (_cityCtrl.text.trim().isEmpty) return 'La ville est obligatoire';
      if (_selectedCountry == null) return 'Sélectionne ton pays';
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
    setState(() => _step = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _register() async {
    final error = _validateStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.accent));
      return;
    }
    final success = await ref.read(authProvider.notifier).register(
      email:          _emailCtrl.text.trim(),
      anonymousAlias: _aliasCtrl.text.trim(),
      age:            int.parse(_ageCtrl.text.trim()),
      city:           _cityCtrl.text.trim(),
      country:        _selectedCountry!,
      gender:         _gender,
      password:       _passCtrl.text,
      legalAccepted:  true,
    );
    if (success && mounted) {
      final user = ref.read(authProvider).user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('needs_onboarding', true);
      final needsVerif = user?.email != null && user?.isEmailVerified != true;
      if (mounted) context.go(needsVerif ? '/verify-email' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor  = isDark ? Colors.white12 : AppColors.divider;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () {
          if (_step > 0) setState(() => _step = 0);
          else if (Navigator.of(context).canPop()) context.pop();
          else context.go('/auth/login');
        }),
        title: Text('Étape ${_step + 1} sur 2',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_step + 1) / 2,
            backgroundColor: borderColor,
            color: AppColors.primary,
            minHeight: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Header ──────────────────────────────────────────────────────
            Center(child: Container(
              width: 56, height: 56,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: const BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.md),
              child: ClipRRect(borderRadius: AppRadius.md,
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
            )),

            if (_step == 0) ...[
              Text('Crée ton compte', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('Quelques infos pour commencer.',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
            ] else ...[
              Text('Presque fini !', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text('Ces informations restent privées.',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
            ],
            const SizedBox(height: 20),

            // ── Erreur API ────────────────────────────────────────────────
            if (state.error != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent))),
                ]),
              ),
            ],

            // ── ÉTAPE 1 ───────────────────────────────────────────────────
            if (_step == 0) ...[
              // Card formulaire
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // Email
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () { _validateEmail(); _aliasFocus.requestFocus(); },
                    onChanged: (_) { if (_emailCtrl.text.isNotEmpty) _validateEmail(); },
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: _emailError,
                      suffixIcon: _emailCtrl.text.isNotEmpty
                          ? Icon(_emailError == null ? Icons.check_circle : Icons.error,
                              color: _emailError == null ? Colors.green : AppColors.accent, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pseudo
                  TextField(
                    controller: _aliasCtrl,
                    focusNode: _aliasFocus,
                    maxLength: 30,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () => _passFocus.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'Pseudo anonyme (optionnel)',
                      hintText: 'Ex: 🌙 Lune curieuse',
                      prefixIcon: const Icon(Icons.face_outlined),
                      counterStyle: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                      helperText: 'Ce pseudo sera visible dans la communauté',
                      helperStyle: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Mot de passe
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
                        icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        splashRadius: 20,
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Confirmer MDP
                  TextField(
                    controller: _confirmCtrl,
                    focusNode: _confirmFocus,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _nextStep(),
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: _confirmCtrl.text.isNotEmpty
                          ? Icon(
                              _passCtrl.text == _confirmCtrl.text ? Icons.check_circle : Icons.error,
                              color: _passCtrl.text == _confirmCtrl.text ? Colors.green : AppColors.accent,
                              size: 18)
                          : IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              splashRadius: 20,
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // ── CGU — card séparée bien visible ────────────────────────
              GestureDetector(
                onTap: () => setState(() => _legalAccepted = !_legalAccepted),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _legalAccepted
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _legalAccepted ? AppColors.primary : borderColor,
                      width: _legalAccepted ? 1.5 : 1,
                    ),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Checkbox custom
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _legalAccepted ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: _legalAccepted ? AppColors.primary : (isDark ? Colors.white54 : Colors.grey.shade400),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _legalAccepted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? Colors.white : Colors.grey.shade800,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: "J'accepte les "),
                          TextSpan(
                            text: "conditions générales d'utilisation",
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              height: 1.5,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => context.push('/legal-terms'),
                          ),
                          const TextSpan(text: " de LinkMind *"),
                        ],
                      ),
                    )),
                  ]),
                ),
              ),
            ],

            // ── ÉTAPE 2 ───────────────────────────────────────────────────
            if (_step == 1) ...[
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // Âge
                  TextField(
                    controller: _ageCtrl,
                    focusNode: _ageFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () { _validateAge(); _cityFocus.requestFocus(); },
                    onChanged: (_) { if (_ageCtrl.text.isNotEmpty) _validateAge(); },
                    decoration: InputDecoration(
                      labelText: 'Âge *',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      hintText: 'Ex: 22',
                      errorText: _ageError,
                      suffixIcon: _ageCtrl.text.isNotEmpty
                          ? Icon(_ageError == null ? Icons.check_circle : Icons.error,
                              color: _ageError == null ? Colors.green : AppColors.accent, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Ville
                  TextField(
                    controller: _cityCtrl,
                    focusNode: _cityFocus,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Ville *',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pays
                  if (_loadingCountries)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    Theme(
                      data: Theme.of(context).copyWith(
                        // Agrandir la zone de tap du dropdown
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        isExpanded: true,
                        icon: const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Pays *',
                          prefixIcon: Icon(Icons.public_outlined),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        hint: const Text('Sélectionne ton pays'),
                        items: _countries.map((c) =>
                            DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _selectedCountry = v),
                      ),
                    ),
                ]),
              ),

              const SizedBox(height: 16),

              // Genre
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Genre (optionnel)',
                      style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700, color: AppColors.onSurfaceMuted)),
                  const SizedBox(height: 4),
                  ..._genders.map((g) => RadioListTile<String>(
                    value: g.$1,
                    groupValue: _gender,
                    onChanged: (v) => setState(() => _gender = _gender == v ? null : v),
                    title: Text(g.$2, style: AppTextStyles.body),
                    dense: true,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  )),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── Bouton principal ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : (_step == 0 ? _nextStep : _register),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: state.isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _step == 0 ? 'Continuer →' : 'Créer mon compte',
                        style: AppTextStyles.button.copyWith(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),

            if (_step == 0) ...[
              const SizedBox(height: 16),
              Center(child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted),
                  children: [
                    const TextSpan(text: 'Déjà un compte ? '),
                    TextSpan(
                      text: 'Se connecter',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700),
                      recognizer: TapGestureRecognizer()..onTap = () => context.go('/auth/login'),
                    ),
                  ],
                ),
              )),
            ],

          ]),
        ),
      ),
    );
  }
}

// ─── Widget erreur ────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool isNetwork;
  const _ErrorBanner({required this.message, required this.isNetwork});

  @override
  Widget build(BuildContext context) {
    final color = isNetwork ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(children: [
        Icon(isNetwork ? Icons.wifi_off : Icons.error_outline, color: color.shade700, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: TextStyle(color: color.shade800, fontSize: 13))),
      ]),
    );
  }
} 