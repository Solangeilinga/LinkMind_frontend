import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';
import '../../utils/legal_texts.dart';

// ─── Bouton SOS discret — à placer dans l'AppBar de Mindo ────────────────────
class SosButton extends StatelessWidget {
  const SosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showSosDialog(context),
      tooltip: 'Urgence',
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: AppRadius.full,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emergency_outlined, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text('SOS', style: AppTextStyles.caption.copyWith(
              color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 11)),
        ])),
    );
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle),
              child: const Center(child: Text('🆘', style: TextStyle(fontSize: 32)))),
            const SizedBox(height: 16),
            Text('Tu traverses une crise ?',
                style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Tu n\'es pas seul(e). Des personnes sont là pour t\'aider maintenant.',
              style: AppTextStyles.body.copyWith(
                  color: AppColors.onSurfaceMuted, height: 1.5),
              textAlign: TextAlign.center),
            const SizedBox(height: 20),

            // Bouton SAMU
            _SosCallButton(
              emoji: '🏥',
              label: 'SAMU',
              sublabel: 'Urgences médicales — 24h/24',
              number: '15',
              color: AppColors.accent,
            ),
            const SizedBox(height: 10),
            _SosCallButton(
              emoji: '🚔',
              label: 'Police secours',
              sublabel: 'Sécurité',
              number: '17',
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            _SosCallButton(
              emoji: '🚒',
              label: 'Pompiers',
              sublabel: 'Accidents — incendies',
              number: '18',
              color: AppColors.accentOrange,
            ),
            const SizedBox(height: 20),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.md),
              child: Text(
                'Si tu as des pensées de te faire du mal, appelle le 15 immédiatement. Mindo ne peut pas gérer les urgences.',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted, height: 1.4),
                textAlign: TextAlign.center)),
            const SizedBox(height: 16),

            // Fermer
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Je vais mieux, fermer')),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SosCallButton extends StatelessWidget {
  final String emoji, label, sublabel, number;
  final Color color;

  const _SosCallButton({
    required this.emoji, required this.label,
    required this.sublabel, required this.number, required this.color,
  });

  Future<void> _call() async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _call,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.md,
          border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w800, color: color)),
            Text(sublabel, style: AppTextStyles.caption.copyWith(
                color: AppColors.onSurfaceMuted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.full),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.phone, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(number, style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800)),
            ])),
        ])),
    );
  }
}

// ─── Disclaimer médical court (dans AppBar Mindo) ─────────────────────────────
class MedicalDisclaimerBanner extends StatelessWidget {
  const MedicalDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.accentOrange.withValues(alpha: 0.08),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 13, color: AppColors.accentOrange),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            LegalTexts.mindoShortDisclaimer,
            style: AppTextStyles.caption.copyWith(
                color: AppColors.accentOrange, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis)),
      ]));
  }
}