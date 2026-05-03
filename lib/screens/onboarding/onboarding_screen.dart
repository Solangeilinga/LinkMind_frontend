import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api.service.dart';

class _Slide {
  final String emoji, title, body;
  final Color color;
  final List<(String, String)> features;
  const _Slide({required this.emoji, required this.title, required this.body, required this.color, this.features = const []});
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  final List<String> _selectedGoals = [];
  String _reminderTime = '20:00';
  bool _isSaving = false;

  static const _goals = [
    ('😌', 'Gérer mon stress'),('😴', 'Mieux dormir'),('💪', 'Rester motivé(e)'),
    ('🤝', 'Me sentir moins seul(e)'),('📚', 'Réussir mes études'),
    ('😊', 'Être plus heureux(se)'),('🧘', 'Développer la pleine conscience'),
    ('🏃', 'Adopter de bonnes habitudes'),
  ];

  static const _slides = [
    _Slide(emoji: '🧠', title: 'Bienvenue sur LinkMind',
      body: 'Ton espace personnel pour prendre soin de ta santé mentale, chaque jour, à ton rythme.',
      color: Color(0xFF77021D),
      features: [('🔒','Anonymat total'),('🌍','Conçu pour l\'Afrique'),('💚','Bienveillant & sûr')]),
    _Slide(emoji: '😊', title: 'Suis ton humeur au quotidien',
      body: 'Enregistre comment tu te sens en quelques secondes. Visualise ton évolution et découvre tes tendances émotionnelles.',
      color: Color(0xFF1D9E75),
      features: [('📊','Graphique 7 jours'),('🔥','Streak consécutif'),('⚡','Points & niveaux')]),
    _Slide(emoji: '🤖', title: 'Mindo, ton assistant IA',
      body: 'Parle à Mindo à tout moment. Il t\'écoute, t\'analyse et propose des exercices personnalisés selon ton état.',
      color: Color(0xFF378ADD),
      features: [('💬','10 messages/jour gratuits'),('🚨','Détecte les crises'),('🩺','Oriente vers un pro')]),
    _Slide(emoji: '🏆', title: 'Des défis pour aller mieux',
      body: 'Chaque jour, des défis adaptés à ton humeur : respiration, méditation, gratitude. Termine-les pour gagner des points.',
      color: Color(0xFFBA7517),
      features: [('⏱️','Défis chronométrés'),('💭','Exercices de réflexion'),('🏅','Badges à débloquer')]),
    _Slide(emoji: '🌍', title: 'Une communauté bienveillante',
      body: 'Partage anonymement ce que tu ressens, encourage les autres et reçois du soutien. Un espace sans jugement.',
      color: Color(0xFF7C3AED),
      features: [('🎭','Pseudonyme anonyme'),('❤️','Réactions & soutien'),('🛡️','Modération active')]),
    _Slide(emoji: '🩺', title: 'Des professionnels à portée',
      body: 'Besoin d\'un accompagnement ? Consulte des psychologues, coachs et médecins partenaires, en ligne ou près de chez toi.',
      color: Color(0xFF0EA5E9),
      features: [('🌐','En ligne ou présentiel'),('💰','Tarifs en FCFA'),('🔒','Demande anonyme')]),
  ];

  bool get _isSlide => _step < _slides.length;
  bool get _isGoals => _step == _slides.length;

  void _next() {
    if (_isSlide) {
      if (_step < _slides.length - 1) {
        _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        // _step mis à jour par onPageChanged ↓
      } else {
        setState(() => _step = _slides.length);
      }
    } else if (_isGoals) {
      setState(() => _step = _slides.length + 1);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final isNewUser = prefs.getBool('needs_onboarding') ?? false;
    await prefs.setBool('onboarding_done', true);
    await prefs.setBool('needs_onboarding', false);
    await prefs.setStringList('user_goals', _selectedGoals);
    await prefs.setString('reminder_time', _reminderTime);

    // Persister en backend si connecté
    try {
      if (ref.read(authProvider).user != null) {
        await ApiService().patch('/users/me', {
          'preferences': {'goals': _selectedGoals, 'reminderTime': _reminderTime},
        });
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSaving = false);
    context.go(isNewUser ? '/home' : '/auth/login');
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final totalSteps = _slides.length + 2;
    final isReminder = _step == _slides.length + 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Barre de progression
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            ...List.generate(totalSteps, (i) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i <= _step ? AppColors.primary : AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
              ))),
            if (_isSlide)
              TextButton(
                onPressed: () => setState(() => _step = _slides.length),
                child: Text('Passer', style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted))),
          ]),
        ),

        // Contenu
        Expanded(
          child: _isSlide
            ? PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _step = i),
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              )
            : _isGoals ? _buildGoals() : _buildReminder(),
        ),

        // Bouton
        Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
          child: _isSlide
            ? SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _slides[_step].color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.md)),
                  child: Text(
                    _step < _slides.length - 1 ? 'Suivant →' : 'Personnaliser mon expérience',
                    style: AppTextStyles.button.copyWith(color: Colors.white)),
                ))
            : _isGoals
              ? SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedGoals.isNotEmpty ? _next : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.divider,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.md)),
                    child: Text(
                      _selectedGoals.isEmpty
                        ? 'Choisis au moins un objectif'
                        : 'Continuer (${_selectedGoals.length} sélectionné${_selectedGoals.length > 1 ? "s" : ""})',
                      style: AppTextStyles.button.copyWith(color: Colors.white)),
                  ))
              : Column(children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _finish,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.md)),
                      child: _isSaving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text("C'est parti ! 🚀",
                            style: AppTextStyles.button.copyWith(color: Colors.white)),
                    )),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isSaving ? null : _finish,
                    child: Text('Configurer plus tard',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted))),
                ]),
        ),
      ])),
    );
  }

  Widget _buildSlide(_Slide slide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 20),
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(color: slide.color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Center(child: Text(slide.emoji, style: const TextStyle(fontSize: 52)))),
        const SizedBox(height: 24),
        Text(slide.title, style: AppTextStyles.h2, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(slide.body,
          style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.6),
          textAlign: TextAlign.center),
        if (slide.features.isNotEmpty) ...[
          const SizedBox(height: 28),
          Wrap(
            spacing: 10, runSpacing: 10,
            alignment: WrapAlignment.center,
            children: slide.features.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: slide.color.withValues(alpha: 0.08),
                borderRadius: AppRadius.full,
                border: Border.all(color: slide.color.withValues(alpha: 0.25))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(f.$1, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(f.$2, style: AppTextStyles.caption.copyWith(
                    color: slide.color, fontWeight: FontWeight.w700)),
              ]))).toList()),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildGoals() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quels sont tes objectifs ?', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('On personnalisera ton expérience selon tes choix. Sélectionne tout ce qui te correspond.',
          style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.5)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _goals.map((g) {
            final sel = _selectedGoals.contains(g.$2);
            return GestureDetector(
              onTap: () => setState(() {
                if (sel) _selectedGoals.remove(g.$2); else _selectedGoals.add(g.$2);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                  borderRadius: AppRadius.full,
                  border: Border.all(color: sel ? AppColors.primary : AppColors.divider, width: sel ? 1.5 : 1),
                  boxShadow: sel ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 6)] : null),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(g.$1, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(g.$2, style: AppTextStyles.bodySmall.copyWith(
                    color: sel ? AppColors.primary : AppColors.onSurface,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
                  if (sel) ...[const SizedBox(width: 6), const Icon(Icons.check, size: 14, color: AppColors.primary)],
                ])));
          }).toList()),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildReminder() {
    final hours = List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ton rappel quotidien', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('On te rappellera de noter ton humeur chaque jour. Modifiable à tout moment dans les paramètres.',
          style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.5)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.divider),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
          child: Column(children: [
            const Text('⏰', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text('À quelle heure ?', style: AppTextStyles.h4),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _reminderTime,
              decoration: InputDecoration(
                filled: true, fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              items: hours.map((h) => DropdownMenuItem(value: h, child: Text(h, style: AppTextStyles.body))).toList(),
              onChanged: (v) => setState(() => _reminderTime = v ?? '20:00')),
          ])),
        const SizedBox(height: 16),
        if (_selectedGoals.isNotEmpty) ...[
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06), borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tes objectifs :', style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6,
                children: _selectedGoals.map((g) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.full),
                  child: Text(g, style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)))).toList()),
            ])),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: AppRadius.md),
          child: Row(children: [
            const Text('💡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(
              'Les utilisateurs qui notent leur humeur régulièrement se sentent mieux en seulement 2 semaines.',
              style: AppTextStyles.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700, height: 1.4))),
          ])),
        const SizedBox(height: 20),
      ]),
    );
  }
}