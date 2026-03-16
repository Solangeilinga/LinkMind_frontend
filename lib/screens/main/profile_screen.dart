import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api.service.dart';
import '../../models/models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<Map<String, dynamic>> _allBadges = [];

  @override
  void initState() { super.initState(); _loadBadges(); }

  Future<void> _loadBadges() async {
    try {
      final data = await ApiService().getMe();
      if (mounted) setState(() {
        _allBadges = List<Map<String, dynamic>>.from(data['badges'] ?? []);
      });
    } catch (_) {}
  }

  void _showEditSheet() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: user,
        onSaved: (updated) => ref.read(authProvider.notifier).updateUser(updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Header ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Mon profil', style: AppTextStyles.h2),
                IconButton(
                  onPressed: _showEditSheet,
                  icon: const Icon(Icons.edit_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    foregroundColor: AppColors.primary),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Carte profil ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: AppRadius.lg),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: AppTextStyles.h3.copyWith(color: Colors.white)),
                    if (user.anonymousAlias != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Text('🎭', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(user.anonymousAlias!,
                            style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                      ]),
                    ],
                    // Infos perso
                    if (user.city != null || user.age != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        if (user.city != null) ...[
                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.white60),
                          const SizedBox(width: 3),
                          Text(user.city!, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                        ],
                        if (user.city != null && user.age != null)
                          const Text(' · ', style: TextStyle(color: Colors.white54)),
                        if (user.age != null)
                          Text('${user.age} ans',
                              style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      _StatChip('⚡ ${user.totalPoints}', 'Points'),
                      const SizedBox(width: 8),
                      _StatChip('🔥 ${user.streakDays}', 'Jours'),
                      const SizedBox(width: 8),
                      _StatChip('🏅 ${user.levelLabel}', 'Niveau'),
                    ]),
                  ])),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Infos de contact ──
              if (user.email != null || user.phone != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: AppRadius.lg,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                  child: Column(children: [
                    if (user.email != null)
                      _InfoRow(Icons.email_outlined, 'Email', user.email!),
                    if (user.email != null && user.phone != null)
                      const Divider(height: 16),
                    if (user.phone != null)
                      _InfoRow(Icons.phone_outlined, 'Téléphone', user.phone!),
                  ]),
                ),
              if (user.email != null || user.phone != null) const SizedBox(height: 12),

              // ── Progression ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: AppRadius.lg,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Progression — ${user.levelLabel}', style: AppTextStyles.h4),
                    Text('${user.totalPoints} pts',
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: AppRadius.full,
                    child: LinearProgressIndicator(
                      value: user.levelProgress / 100,
                      backgroundColor: AppColors.divider,
                      color: AppColors.primary,
                      minHeight: 10)),
                  const SizedBox(height: 6),
                  Text('${user.levelProgress}% vers le niveau suivant',
                      style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Premium ──
              if (!user.isPremium)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary, borderRadius: AppRadius.lg),
                  child: Row(children: [
                    const Text('👑', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('LinkMind Premium',
                          style: AppTextStyles.h4.copyWith(color: Colors.white)),
                      Text('Méditations guidées, suivi avancé',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.md),
                      child: Text('Essayer', style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w900))),
                  ]),
                ),
              const SizedBox(height: 20),

              // ── Badges ──
              Text('Mes badges', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _allBadges.map((b) {
                  final earned = b['earned'] == true;
                  return AnimatedOpacity(
                    opacity: earned ? 1.0 : 0.35,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 80, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: earned
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.divider.withValues(alpha: 0.5),
                        borderRadius: AppRadius.md,
                        border: Border.all(
                          color: earned
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.transparent)),
                      child: Column(children: [
                        Text(b['icon'] ?? '🏅',
                            style: const TextStyle(fontSize: 28),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text(b['name'] ?? '',
                            style: AppTextStyles.caption.copyWith(
                              color: earned ? AppColors.onSurface : AppColors.onSurfaceMuted),
                            textAlign: TextAlign.center, maxLines: 2),
                      ]),
                    ),
                  );
                }).toList()),
              const SizedBox(height: 24),

              // ── Déconnexion ──
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/auth/login');
                },
                icon: const Icon(Icons.logout, color: AppColors.accent),
                label: Text('Se déconnecter',
                    style: AppTextStyles.button.copyWith(color: AppColors.accent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent),
                  minimumSize: const Size(double.infinity, 52)),
              ),
              const SizedBox(height: 100),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppColors.primary),
    const SizedBox(width: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
      Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
    ]),
  ]);
}

// ─── Edit Profile Sheet ───────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final UserModel user;
  final Function(UserModel) onSaved;
  const _EditProfileSheet({required this.user, required this.onSaved});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _aliasCtrl;
  late final TextEditingController _currentPassCtrl;
  late final TextEditingController _newPassCtrl;

  late final TextEditingController _ageCtrl;
  String? _gender;
  bool    _saving          = false;
  bool    _showPassSection = false;
  bool    _obscureCurrent  = true;
  bool    _obscureNew      = true;
  String? _error;
  String? _success;

  static const _genders = [
    ('homme',        '👨 Homme'),
    ('femme',        '👩 Femme'),
    ('non_specifie', '— Préfère ne pas préciser'),
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _firstNameCtrl   = TextEditingController(text: u.firstName ?? '');
    _lastNameCtrl    = TextEditingController(text: u.lastName  ?? '');
    _emailCtrl       = TextEditingController(text: u.email     ?? '');
    _phoneCtrl       = TextEditingController(text: u.phone     ?? '');
    _cityCtrl        = TextEditingController(text: u.city      ?? '');
    _aliasCtrl       = TextEditingController(text: u.anonymousAlias ?? '');
    _ageCtrl         = TextEditingController(text: u.age != null ? '${u.age}' : '');
    _currentPassCtrl = TextEditingController();
    _newPassCtrl     = TextEditingController();
    _gender          = u.gender;
  }

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl,
        _cityCtrl, _aliasCtrl, _ageCtrl, _currentPassCtrl, _newPassCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName  = _lastNameCtrl.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Prénom et nom sont obligatoires');
      return;
    }
    setState(() { _saving = true; _error = null; _success = null; });
    try {
      final data = await ApiService().updateProfile({
        'firstName':      firstName,
        'lastName':       lastName,
        'name':           '$firstName $lastName',
        'email':          _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'phone':          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'city':           _cityCtrl.text.trim().isEmpty  ? null : _cityCtrl.text.trim(),
        'anonymousAlias': _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
        if (_ageCtrl.text.trim().isNotEmpty) 'age': int.tryParse(_ageCtrl.text.trim()),
        if (_gender != null) 'gender': _gender,
      });
      final updated = UserModel.fromJson(data['user']);
      widget.onSaved(updated);
      if (mounted) setState(() { _saving = false; _success = 'Profil mis à jour ✅'; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Une erreur est survenue'; });
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPassCtrl.text;
    final newPass  = _newPassCtrl.text;
    if (current.isEmpty || newPass.isEmpty) {
      setState(() => _error = 'Remplis les deux champs');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'Le nouveau mot de passe doit faire au moins 6 caractères');
      return;
    }
    setState(() { _saving = true; _error = null; _success = null; });
    try {
      await ApiService().post('/auth/change-password', {
        'currentPassword': current,
        'newPassword':     newPass,
      });
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      if (mounted) setState(() {
        _saving = false;
        _success = 'Mot de passe modifié ✅';
        _showPassSection = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Une erreur est survenue'; });
    }
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: AppTextStyles.h4),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Handle
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: AppRadius.full))),
            const SizedBox(height: 16),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Modifier le profil', style: AppTextStyles.h3),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20)),
            ]),
            const SizedBox(height: 8),

            // Feedback
            if (_error != null) _FeedbackBanner(message: _error!, isError: true),
            if (_success != null) _FeedbackBanner(message: _success!, isError: false),

            // ── Identité ──
            _sectionTitle('Identité'),
            Row(children: [
              Expanded(child: TextField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Prénom *'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: _lastNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom *'))),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone_outlined),
                helperText: 'Format international: +22661645069')),
            const SizedBox(height: 20),

            // ── Infos personnelles ──
            _sectionTitle('Infos personnelles'),
            TextField(
              controller: _cityCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ville',
                prefixIcon: Icon(Icons.location_city_outlined))),
            const SizedBox(height: 16),

            // Âge
            TextField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Âge',
                prefixIcon: Icon(Icons.cake_outlined),
                hintText: 'Ex: 20')),
            const SizedBox(height: 16),

            // Genre
            Text('Genre', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
            ...(_genders.map((g) => RadioListTile<String>(
              value: g.$1,
              groupValue: _gender,
              onChanged: (v) => setState(() => _gender = _gender == v ? null : v),
              title: Text(g.$2, style: AppTextStyles.body),
              dense: true,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ))).toList(),
            const SizedBox(height: 20),

            // ── Communauté ──
            _sectionTitle('Communauté'),
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
            const SizedBox(height: 24),

            // ── Sauvegarder ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer les modifications'),
              ),
            ),
            const SizedBox(height: 20),

            // ── Mot de passe ──
            GestureDetector(
              onTap: () => setState(() { _showPassSection = !_showPassSection; _error = null; }),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.md),
                child: Row(children: [
                  const Icon(Icons.lock_outline, size: 18, color: AppColors.onSurfaceMuted),
                  const SizedBox(width: 10),
                  Text('Changer le mot de passe',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Icon(_showPassSection ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.onSurfaceMuted),
                ]),
              ),
            ),
            if (_showPassSection) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _currentPassCtrl,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Mot de passe actuel',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent)))),
              const SizedBox(height: 12),
              TextField(
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe (min. 6 car.)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew)))),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saving ? null : _changePassword,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(48)),
                  child: const Text('Confirmer le nouveau mot de passe'),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

// ─── Feedback Banner ──────────────────────────────────────────────────────────
class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.accent : AppColors.secondary;
    final icon  = isError ? Icons.error_outline : Icons.check_circle_outline;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: AppTextStyles.bodySmall.copyWith(color: color))),
      ]),
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String value, label;
  const _StatChip(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: AppTextStyles.caption.copyWith(
        color: Colors.white, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60)),
  ]);
}