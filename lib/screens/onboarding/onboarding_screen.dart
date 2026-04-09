import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  final List<String> _selectedGoals = [];
  String _reminderTime = '20:00';

  static const _goals = [
    ('😌', 'Gérer mon stress'),
    ('😴', 'Mieux dormir'),
    ('💪', 'Rester motivé(e)'),
    ('🤝', 'Me sentir moins seul(e)'),
    ('📚', 'Réussir mes études'),
    ('😊', 'Être plus heureux(se)'),
  ];

  static const _slides = [
    _Slide(
      emoji: '🧠',
      title: 'Bienvenue sur LinkMind',
      body: 'Ton espace personnel pour prendre soin de ta santé mentale, chaque jour, à ton rythme.',
      color: Color(0xFF77021D),
    ),
    _Slide(
      emoji: '😊',
      title: 'Suis ton humeur',
      body: 'Enregistre comment tu te sens chaque jour. Mindo t\'aide à comprendre tes émotions et te propose des exercices adaptés.',
      color: Color(0xFF1D9E75),
    ),
    _Slide(
      emoji: '🌍',
      title: 'Une communauté bienveillante',
      body: 'Partage anonymement, encourage les autres, reçois du soutien. Ici, personne ne te juge.',
      color: Color(0xFF378ADD),
    ),
    _Slide(
      emoji: '🩺',
      title: 'Des professionnels disponibles',
      body: 'Besoin d\'un accompagnement ? Consulte des psychologues et coachs disponibles près de chez toi ou en ligne.',
      color: Color(0xFFBA7517),
    ),
  ];

  void _next() {
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else if (_page == _slides.length - 1) {
      // Passer à la sélection des objectifs
      setState(() => _page = _slides.length);
    } else if (_page == _slides.length) {
      // Passer au rappel
      setState(() => _page = _slides.length + 1);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    await prefs.setStringList('user_goals', _selectedGoals);
    await prefs.setString('reminder_time', _reminderTime);
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isSlide = _page < _slides.length;
    final isGoals = _page == _slides.length;
    final isReminder = _page == _slides.length + 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Indicateur de progression
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              ...List.generate(_slides.length + 2, (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i <= _page ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
                ))),
              // Bouton passer
              if (isSlide)
                TextButton(
                  onPressed: () => setState(() => _page = _slides.length),
                  child: Text('Passer', style: AppTextStyles.caption.copyWith(
                      color: AppColors.onSurfaceMuted))),
            ]),
          ),

          Expanded(child: isSlide
            ? _buildSlide(_slides[_page])
            : isGoals
              ? _buildGoals()
              : _buildReminder()),

          // Bouton bas
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
            child: Column(children: [
              if (isSlide) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: _slides[_page].color),
                    child: Text(
                      _page < _slides.length - 1 ? 'Suivant' : 'Commencer',
                      style: AppTextStyles.button.copyWith(color: Colors.white)),
                  )),
              ] else if (isGoals) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedGoals.isNotEmpty ? _next : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.divider),
                    child: Text('Continuer (${_selectedGoals.length} sélectionné${_selectedGoals.length > 1 ? "s" : ""})',
                        style: AppTextStyles.button.copyWith(color: Colors.white)),
                  )),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.primary),
                    child: Text("C'est parti ! 🚀",
                        style: AppTextStyles.button.copyWith(color: Colors.white)),
                  )),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _finish,
                  child: Text('Configurer plus tard',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted))),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildSlide(_Slide slide) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: slide.color.withValues(alpha: 0.1),
              shape: BoxShape.circle),
            child: Center(
              child: Text(slide.emoji, style: const TextStyle(fontSize: 56)))),
          const SizedBox(height: 36),
          Text(slide.title, style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(slide.body,
            style: AppTextStyles.body.copyWith(
                color: AppColors.onSurfaceMuted, height: 1.7),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildGoals() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Text('Quels sont tes objectifs ?', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('Choisis tout ce qui te correspond (au moins 1).',
            style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _goals.map((g) {
            final sel = _selectedGoals.contains(g.$2);
            return GestureDetector(
              onTap: () => setState(() {
                if (sel) _selectedGoals.remove(g.$2);
                else _selectedGoals.add(g.$2);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                  borderRadius: AppRadius.full,
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.divider,
                    width: sel ? 1.5 : 1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(g.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(g.$2, style: AppTextStyles.bodySmall.copyWith(
                    color: sel ? AppColors.primary : AppColors.onSurface,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
                ])));
          }).toList()),
      ]),
    );
  }

  Widget _buildReminder() {
    final hours = List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Text('Ton rappel quotidien', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          'On te rappelle de noter ton humeur chaque jour. Tu peux changer ça dans les paramètres.',
          style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.6)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.divider)),
          child: Column(children: [
            const Text('⏰', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('À quelle heure ?', style: AppTextStyles.h4),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _reminderTime,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              items: hours.map((h) => DropdownMenuItem(
                value: h,
                child: Text(h, style: AppTextStyles.body))).toList(),
              onChanged: (v) => setState(() => _reminderTime = v ?? '20:00'),
            ),
          ])),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.08),
            borderRadius: AppRadius.md),
          child: Row(children: [
            const Text('💡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(
              'Les utilisateurs qui notent leur humeur régulièrement se sentent mieux en seulement 2 semaines.',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondary, fontWeight: FontWeight.w700, height: 1.4))),
          ])),
      ]),
    );
  }
}

class _Slide {
  final String emoji, title, body;
  final Color color;
  const _Slide({required this.emoji, required this.title, required this.body, required this.color});
}