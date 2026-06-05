import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../../utils/theme.dart';
import '../../utils/icon_mapper.dart';
import '../../providers/auth_provider.dart';
import '../../services/api.service.dart';

class _Slide {
  final String emoji, title, body;
  final Color color, gradientColor;
  final List<(String, String)> features;
  final String? lottieAnimation;
  const _Slide({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
    required this.gradientColor,
    this.features = const [],
    this.lottieAnimation,
  });
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
    ('😌', 'Gérer mon stress'),
    ('😴', 'Mieux dormir'),
    ('💪', 'Rester motivé(e)'),
    ('🤝', 'Me sentir moins seul(e)'),
    ('📚', 'Réussir mes études'),
    ('😊', 'Être plus heureux(se)'),
    ('🧘', 'Développer la pleine conscience'),
    ('🏃', 'Adopter de bonnes habitudes'),
  ];

  static const _slides = [
    _Slide(
      emoji: '🧠',
      title: 'Bienvenue sur LinkMind',
      body:
          'Ton espace personnel pour prendre soin de ta santé mentale, chaque jour, à ton rythme.',
      color: Color(0xFF6B21A8),
      gradientColor: Color(0xFFA78BFA),
      features: [
        ('🔒', 'Anonymat total'),
        ('🌍', 'Conçu pour l\'Afrique'),
        ('💚', 'Bienveillant & sûr'),
      ],
    ),
    _Slide(
      emoji: '📊',
      title: 'Suis ton humeur au quotidien',
      body:
          'Enregistre tes émotions en 5 secondes. Vois ton évolution en graphique et comprends tes patterns.',
      color: Color(0xFF059669),
      gradientColor: Color(0xFF6EE7B7),
      features: [
        ('📈', 'Graphique 7 jours'),
        ('🔥', '7 jours consécutifs'),
        ('⚡', 'Points & badges'),
      ],
    ),
    _Slide(
      emoji: '🤖',
      title: 'Mindo, ton Assistant personnelle',
      body:
          'Discute avec Mindo, ton assistant 24/7. Il t\'écoute, te comprend et propose des exercices sur mesure.',
      color: Color(0xFF2563EB),
      gradientColor: Color(0xFF93C5FD),
      features: [
        ('💬', '10 msg/jour gratuits'),
        ('🚨', 'Gère les crises'),
        ('🩺', 'Oriente vers un pro'),
      ],
    ),
    _Slide(
      emoji: '🏆',
      title: 'Des défis motivants',
      body:
          'Chaque jour : respiration, méditation, gratitude. Relève-les pour débloquer des badges et des points.',
      color: Color(0xFFDC2626),
      gradientColor: Color(0xFFFCA5A5),
      features: [
        ('⏱️', 'Défis rapides'),
        ('💭', 'Exercices guid.'),
        ('🏅', 'Badges & récompenses'),
      ],
    ),
    _Slide(
      emoji: '👥',
      title: 'Une communauté bienveillante',
      body:
          'Partage anonymement, reçois du soutien, encourage les autres. Un espace sans jugement, 100% safe.',
      color: Color(0xFF7C3AED),
      gradientColor: Color(0xFFDDD6FE),
      lottieAnimation: 'assets/animations/community.json',
      features: [
        ('🎭', 'Anonyme toujours'),
        ('❤️', 'Soutien & humour'),
        ('🛡️', 'Modos actifs'),
      ],
    ),
    _Slide(
      emoji: '⭐',
      title: 'Des pros à ta portée',
      body:
          'Psychologues, coachs, médecins. En ligne ou près de toi. Tarifs justes en FCFA. Prise en charge anonyme.',
      color: Color(0xFFFB923C),
      gradientColor: Color(0xFFFED7AA),
      features: [
        ('🌐', 'En ligne ou présentiel'),
        ('💰', 'Tarifs FCFA justes'),
        ('🔒', 'Anonyme toujours'),
      ],
    ),
  ];

  bool get _isSlide => _step < _slides.length;
  bool get _isGoals => _step == _slides.length;

  void _next() {
    if (_isSlide) {
      if (_step < _slides.length - 1) {
        _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
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
    await prefs.setBool('onboarding_done', true);
    await prefs.setBool('needs_onboarding', false);
    await prefs.setStringList('user_goals', _selectedGoals);
    await prefs.setString('reminder_time', _reminderTime);

    try {
      if (ref.read(authProvider).user != null) {
        await ApiService().patch('/users/me', {
          'preferences': {
            'goals': _selectedGoals,
            'reminderTime': _reminderTime,
          },
        });
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSaving = false);

    final isLoggedIn = ref.read(authProvider).isAuthenticated;
    context.go(isLoggedIn ? '/home' : '/auth/login');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = _slides.length + 2;
    final isReminder = _step == _slides.length + 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Barre de progression
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  ...List.generate(
                    totalSteps,
                    (i) => Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          gradient: i <= _step
                              ? LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withValues(alpha: 0.6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: i <= _step ? null : AppColors.divider,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: i <= _step
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (_isSlide)
                    TextButton(
                      onPressed: () => setState(() => _step = _slides.length),
                      child: Text(
                        'Passer',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
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
                  : _isGoals
                      ? _buildGoals()
                      : _buildReminder(),
            ),

            // Bouton
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: _isSlide
                  ? SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _slides[_step].color,
                              _slides[_step].gradientColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: AppRadius.md,
                          boxShadow: [
                            BoxShadow(
                              color: _slides[_step].color.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _next,
                            borderRadius: AppRadius.md,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  _step < _slides.length - 1
                                      ? 'Suivant →'
                                      : 'Mes objectifs',
                                  style: AppTextStyles.button.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : _isGoals
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _selectedGoals.isNotEmpty ? _next : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.divider,
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppRadius.md,
                              ),
                            ),
                            child: Text(
                              _selectedGoals.isEmpty
                                  ? 'Choisis au moins 1 objectif'
                                  : 'Continuer (${_selectedGoals.length})',
                              style: AppTextStyles.button
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: AppRadius.md,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isSaving ? null : _finish,
                                    borderRadius: AppRadius.md,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Center(
                                        child: _isSaving
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                "C'est parti ! 🚀",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _isSaving ? null : _finish,
                              child: Text(
                                'Configurer plus tard',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.onSurfaceMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_Slide slide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),

          if (slide.lottieAnimation != null)
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    slide.color.withValues(alpha: 0.1),
                    slide.gradientColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: slide.color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Lottie.asset(
                slide.lottieAnimation!,
                repeat: true,
                reverse: false,
              ),
            )
          else
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    slide.color.withValues(alpha: 0.1),
                    slide.gradientColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: slide.color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(slide.emoji, style: const TextStyle(fontSize: 64)),
              ),
            ),

          const SizedBox(height: 32),

          Text(
            slide.title,
            style: AppTextStyles.h2.copyWith(
              color: slide.color,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            slide.body,
            style: AppTextStyles.body.copyWith(
              color: AppColors.onSurfaceMuted,
              height: 1.7,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),

          if (slide.features.isNotEmpty) ...[
            const SizedBox(height: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: slide.features.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: slide.color.withValues(alpha: 0.06),
                      borderRadius: AppRadius.md,
                      border: Border.all(
                        color: slide.color.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: slide.color.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(f.$1, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            f.$2,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: slide.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGoals() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tes objectifs ?', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Text(
            'Choisis ce qui te correspond. On adaptera ton expérience LinkMind.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.onSurfaceMuted,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _goals.map((g) {
              final sel = _selectedGoals.contains(g.$2);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _selectedGoals.remove(g.$2);
                  } else {
                    _selectedGoals.add(g.$2);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.primary.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: sel ? null : AppColors.surface,
                    borderRadius: AppRadius.full,
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.divider,
                      width: sel ? 2 : 1.5,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(g.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        g.$2,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: sel ? AppColors.primary : AppColors.onSurface,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (sel) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReminder() {
    final hours = List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ton rappel quotidien', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Text(
            'À quelle heure tu veux être rappelé(e) ? Modifiable quand tu veux.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.onSurfaceMuted,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.05),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.divider, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('⏰', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('À quelle heure ?', style: AppTextStyles.h4),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _reminderTime,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: const BorderSide(
                        color: AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: const BorderSide(
                        color: AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  items: hours.map((h) {
                    return DropdownMenuItem(
                      value: h,
                      child: Text(
                        h,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _reminderTime = v ?? '20:00'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_selectedGoals.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.lg,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(
                        'Tes objectifs',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedGoals.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.full,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          g,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}