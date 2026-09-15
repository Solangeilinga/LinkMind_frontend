import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';

// ─── Petite visite guidée au premier lancement ──────────────────────────────
// Recommandation d'un coach externe : montrer un aperçu rapide des rubriques
// dès la première visite, avec possibilité de passer. Pas d'asset vidéo dans
// le projet — on réutilise les animations Lottie déjà présentes dans
// l'onboarding plutôt que d'introduire une dépendance video_player pour un
// fichier qui n'existe pas.
class _TourSlide {
  final String emoji, title, body;
  final String? lottieAnimation;
  const _TourSlide({required this.emoji, required this.title, required this.body, this.lottieAnimation});
}

const _tourSlides = [
  _TourSlide(
    emoji: '🌱',
    title: 'Mood — ton suivi quotidien',
    body: 'Enregistre ton humeur chaque jour. Tu verras ta progression et des tendances se dessiner au fil du temps.',
    lottieAnimation: 'assets/animations/yoga_mental_basyam.json',
  ),
  _TourSlide(
    emoji: '👥',
    title: 'Hub — la communauté',
    body: 'Partage ce que tu vis, anonymement, avec une communauté bienveillante qui te comprend.',
    lottieAnimation: 'assets/animations/community_basyam.json',
  ),
  _TourSlide(
    emoji: '🩺',
    title: 'Pros — de l\'aide qualifiée',
    body: 'Psychologues, coachs et médecins disponibles pour un rendez-vous, en ligne ou en personne.',
  ),
  _TourSlide(
    emoji: '⚡',
    title: 'Défis — progresse en t\'amusant',
    body: 'Complète des défis adaptés à ton rythme pour gagner des points et monter de niveau.',
  ),
];

Future<void> maybeShowQuickTour(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('quick_tour_shown') ?? false) return;
  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => const _QuickTourDialog(),
  );
  await prefs.setBool('quick_tour_shown', true);
}

class _QuickTourDialog extends StatefulWidget {
  const _QuickTourDialog();
  @override
  State<_QuickTourDialog> createState() => _QuickTourDialogState();
}

class _QuickTourDialogState extends State<_QuickTourDialog> {
  final _pageCtrl = PageController();
  int _step = 0;

  void _close() => Navigator.of(context).pop();

  void _next() {
    if (_step < _tourSlides.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _close();
    }
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      child: SizedBox(
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(_tourSlides.length, (i) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 4,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: i <= _step ? AppColors.primary : AppColors.divider,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      )),
                    ),
                  ),
                  TextButton(
                    onPressed: _close,
                    child: Text('Passer', style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _tourSlides.length,
                onPageChanged: (i) => setState(() => _step = i),
                itemBuilder: (_, i) => _buildSlide(_tourSlides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                  ),
                  child: Text(
                    _step < _tourSlides.length - 1 ? 'Suivant' : "C'est parti !",
                    style: AppTextStyles.button.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_TourSlide slide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: slide.lottieAnimation != null
                ? Lottie.asset(
                    slide.lottieAnimation!,
                    repeat: true,
                    errorBuilder: (_, __, ___) => Center(child: Text(slide.emoji, style: const TextStyle(fontSize: 56))),
                  )
                : Center(child: Text(slide.emoji, style: const TextStyle(fontSize: 56))),
          ),
          const SizedBox(height: 20),
          Text(slide.title, style: AppTextStyles.h4, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(slide.body, style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
