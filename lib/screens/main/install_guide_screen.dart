import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';

/// Guide d'installation "Ajouter à l'écran d'accueil" — utile en particulier
/// sur les navigateurs qui ne proposent pas la bannière automatique
/// d'installation (Samsung Internet notamment, qui l'a désactivée par choix
/// de conception depuis sa version 27).
class InstallGuideScreen extends StatelessWidget {
  const InstallGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 8),
              const Text('Installer BASYAM', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Trois étapes, une seule fois. Rien à télécharger depuis un store.',
                style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 28),

              // ── Deux blocs Android / iPhone ──────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 520;
                  final androidCard = _PlatformCard(
                    icon: Icons.android,
                    title: 'Android',
                    steps: const [
                      'Touchez les trois points (⋮) en haut à droite du navigateur.',
                      'Choisissez "Ajouter à l\'écran d\'accueil".',
                      'Confirmez "Ajouter". L\'icône BASYAM apparaît avec vos autres applications.',
                    ],
                  );
                  final iosCard = _PlatformCard(
                    icon: Icons.apple,
                    title: 'iPhone',
                    steps: const [
                      'Touchez le bouton de partage (⬆) en bas au milieu de l\'écran.',
                      'Faites défiler, puis choisissez "Sur l\'écran d\'accueil".',
                      'Touchez "Ajouter" en haut à droite. C\'est fait.',
                    ],
                  );

                  if (isWide) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: androidCard),
                          const SizedBox(width: 16),
                          Expanded(child: iosCard),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      androidCard,
                      const SizedBox(height: 16),
                      iosCard,
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Sur certains navigateurs (Samsung Internet notamment), la '
                  'proposition d\'installation automatique n\'apparaît pas — '
                  'ces trois étapes fonctionnent malgré tout, à tout moment.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                ),
              ),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Une fois installée, l\'application s\'ouvre sans navigateur '
                        'et reste accessible même en cas de réseau instable.',
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> steps;

  const _PlatformCard({
    required this.icon,
    required this.title,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(steps[i], style: AppTextStyles.body),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
