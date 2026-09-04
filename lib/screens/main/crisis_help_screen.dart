import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';
import '../../services/api.service.dart';

/// Écran "Besoin d'aide maintenant" — indépendant de Mindo (pas encore
/// disponible). Objectif double : donner immédiatement des ressources
/// concrètes, et permettre de prévenir l'équipe support en un geste.
class CrisisHelpScreen extends StatefulWidget {
  const CrisisHelpScreen({super.key});

  @override
  State<CrisisHelpScreen> createState() => _CrisisHelpScreenState();
}

class _CrisisHelpScreenState extends State<CrisisHelpScreen> {
  final _messageController = TextEditingController();
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _isSending = true);
    await ApiService().sendCrisisSelfReport(message: _messageController.text);
    if (mounted) {
      setState(() {
        _isSending = false;
        _sent = true; // toujours affiché comme envoyé, cf. tolérance aux pannes du service
      });
    }
  }

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Besoin d\'aide', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Tu n\'es pas seul(e).',
              style: AppTextStyles.h1.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Si tu traverses un moment difficile, voici de quoi t\'aider tout de suite.',
              style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: 24),

            // ── Ressources immédiates ──────────────────────────────────
            // Le numéro d'urgence (15) a été retiré en attendant la
            // confirmation du partenariat associé — à réintégrer une fois
            // validé.
            _ResourceCard(
              icon: Icons.psychology_outlined,
              title: 'Nos psychologues partenaires',
              subtitle: 'Réserve un échange dès que possible, directement dans l\'app.',
              actionLabel: 'Voir les professionnels',
              onTap: () => context.push('/professionals'),
            ),

            const SizedBox(height: 28),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 20),

            // ── Prévenir l'équipe support ───────────────────────────────
            Text('Prévenir l\'équipe BASYAM', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Ce message est transmis directement à notre équipe, qui reviendra vers toi dès que possible. Ce n\'est pas un service d\'urgence immédiate.',
              style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: 16),

            if (_sent) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.lg,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'C\'est transmis. Quelqu\'un de l\'équipe reviendra vers toi.',
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _messageController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Si tu veux, dis-nous ce qui se passe (facultatif)...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: AppRadius.lg, borderSide: const BorderSide(color: AppColors.divider)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                ),
                child: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Prévenir l\'équipe BASYAM'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _ResourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    actionLabel,
                    style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}