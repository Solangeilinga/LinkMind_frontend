import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../utils/legal_texts.dart';
import '../../services/api.service.dart';
import '../../providers/auth_provider.dart';

// ─── Écran d'onboarding légal ─────────────────────────────────────────────────
// Affiché une seule fois après la création du compte.
class LegalOnboardingScreen extends ConsumerStatefulWidget {
  const LegalOnboardingScreen({super.key});

  @override
  ConsumerState<LegalOnboardingScreen> createState() => _LegalOnboardingScreenState();
}

class _LegalOnboardingScreenState extends ConsumerState<LegalOnboardingScreen> {
  bool _acceptedCgu        = false;
  bool _acceptedPrivacy    = false;
  bool _confirmedAge       = false;
  bool _isLoading          = false;
  int  _currentStep        = 0; // 0=disclaimer, 1=cgu+privacy, 2=age

  void _next() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  bool get _canProceed {
    if (_currentStep == 0) return true;
    if (_currentStep == 1) return _acceptedCgu && _acceptedPrivacy;
    if (_currentStep == 2) return _confirmedAge;
    return false;
  }

  Future<void> _submit() async {
    if (!_canProceed || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Enregistrer l'acceptation sur le backend
      await ApiService().acceptLegal();
      
      // ✅ CORRECTION: Rafraîchir l'utilisateur pour mettre à jour legalAccepted
      await ref.read(authProvider.notifier).refreshUser();
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      debugPrint('❌ Erreur acceptLegal: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur, réessaie plus tard'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: AppColors.divider,
              color: AppColors.primary,
              minHeight: 3,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStep(_currentStep),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0: return _DisclaimerStep(key: const ValueKey(0));
      case 1: return _LegalStep(
        key: const ValueKey(1),
        acceptedCgu: _acceptedCgu,
        acceptedPrivacy: _acceptedPrivacy,
        onCguChanged: (v) => setState(() => _acceptedCgu = v),
        onPrivacyChanged: (v) => setState(() => _acceptedPrivacy = v),
      );
      case 2: return _AgeStep(
        key: const ValueKey(2),
        confirmed: _confirmedAge,
        onChanged: (v) => setState(() => _confirmedAge = v),
      );
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar() {
    final labels = ['Continuer', 'Accepter et continuer', 'Commencer'];
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.divider))),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canProceed && !_isLoading ? _next : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.divider),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(labels[_currentStep],
                  style: AppTextStyles.button.copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}

// ─── Étape 1 : Disclaimer médical ────────────────────────────────────────────
class _DisclaimerStep extends StatelessWidget {
  const _DisclaimerStep({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle),
            child: const Center(
              child: Text('🏥', style: TextStyle(fontSize: 36)))),
          const SizedBox(height: 24),
          Text('Avant de commencer', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Quelques informations importantes sur LinkMind.',
            style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 28),

          _InfoCard(
            emoji: '🧠',
            color: AppColors.primary,
            title: 'Outil de bien-être',
            body: 'LinkMind t\'aide à prendre soin de toi au quotidien grâce à des exercices, un suivi de ton humeur et une communauté bienveillante.',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            emoji: '⚕️',
            color: AppColors.accentOrange,
            title: 'Pas un service médical',
            body: 'LinkMind et Mindo ne remplacent pas un médecin, un psychologue ou un thérapeute. En cas de crise ou de doute, consulte un professionnel de santé.',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            emoji: '🆘',
            color: AppColors.accent,
            title: 'En cas d\'urgence',
            body: 'Si tu traverses une crise ou as des pensées de te faire du mal, appelle le SAMU (15) immédiatement. LinkMind n\'est pas un service d\'urgence.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
            child: Row(children: [
              const Text('💙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tu es au bon endroit pour prendre soin de toi. On est là pour t\'accompagner.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700, height: 1.5))),
            ])),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Étape 2 : CGU + Politique de confidentialité ────────────────────────────
class _LegalStep extends StatelessWidget {
  final bool acceptedCgu, acceptedPrivacy;
  final ValueChanged<bool> onCguChanged, onPrivacyChanged;

  const _LegalStep({
    super.key,
    required this.acceptedCgu,
    required this.acceptedPrivacy,
    required this.onCguChanged,
    required this.onPrivacyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle),
            child: const Center(child: Text('📋', style: TextStyle(fontSize: 36)))),
          const SizedBox(height: 24),
          Text('Conditions d\'utilisation', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text('Lis et accepte nos conditions pour continuer.',
              style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 24),

          _LegalCheckCard(
            emoji: '📄',
            title: 'Conditions Générales d\'Utilisation',
            description: 'Comment utiliser LinkMind, règles de la communauté, droits et responsabilités.',
            accepted: acceptedCgu,
            onTap: () => _showFullText(context, 'CGU', LegalTexts.cgu),
            onChanged: onCguChanged,
          ),
          const SizedBox(height: 12),

          _LegalCheckCard(
            emoji: '🔒',
            title: 'Politique de confidentialité',
            description: 'Quelles données on collecte, pourquoi, et comment on les protège.',
            accepted: acceptedPrivacy,
            onTap: () => _showFullText(context, 'Confidentialité', LegalTexts.privacy),
            onChanged: onPrivacyChanged,
          ),
          const SizedBox(height: 20),
          Text(
            'En acceptant, tu confirmes avoir lu et compris ces documents.',
            style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showFullText(BuildContext context, String title, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Text(title, style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
              ])),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Text(text,
                    style: AppTextStyles.bodySmall.copyWith(height: 1.7)))),
          ]),
        ),
      ),
    );
  }
}

// ─── Étape 3 : Vérification âge ──────────────────────────────────────────────
class _AgeStep extends StatelessWidget {
  final bool confirmed;
  final ValueChanged<bool> onChanged;

  const _AgeStep({super.key, required this.confirmed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Text('🔞', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text('Vérification d\'âge', style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'LinkMind est réservé aux personnes de 15 ans et plus.',
            style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
            textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lg,
              border: Border.all(
                color: confirmed ? AppColors.secondary : AppColors.divider,
                width: confirmed ? 2 : 1)),
            child: CheckboxListTile(
              value: confirmed,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.secondary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                'Je confirme avoir au moins 15 ans',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Si tu as entre 15 et 18 ans, nous te recommandons d\'informer un parent ou tuteur.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted))),
              controlAffinity: ListTileControlAffinity.leading,
            )),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: AppRadius.md),
            child: Column(children: [
              Text('🌱', style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text('Prêt(e) à prendre soin de toi ?',
                  style: AppTextStyles.h4, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'LinkMind t\'accompagne chaque jour pour mieux gérer ton stress, tes émotions et te connecter à une communauté bienveillante.',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurfaceMuted, height: 1.5),
                textAlign: TextAlign.center),
            ])),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Widgets réutilisables ────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String emoji, title, body;
  final Color color;

  const _InfoCard({
    required this.emoji, required this.title,
    required this.body, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.lg,
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(body, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurface, height: 1.5)),
        ])),
      ]));
  }
}

class _LegalCheckCard extends StatelessWidget {
  final String emoji, title, description;
  final bool accepted;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  const _LegalCheckCard({
    required this.emoji, required this.title, required this.description,
    required this.accepted, required this.onTap, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: accepted ? AppColors.primary : AppColors.divider,
          width: accepted ? 1.5 : 1)),
      child: Column(children: [
        ListTile(
          leading: Text(emoji, style: const TextStyle(fontSize: 24)),
          title: Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800)),
          subtitle: Text(description,
              style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
          trailing: TextButton(
            onPressed: onTap,
            child: Text('Lire', style: AppTextStyles.caption.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w800))),
        ),
        const Divider(height: 1),
        CheckboxListTile(
          value: accepted,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            'J\'ai lu et j\'accepte',
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
      ]));
  }
}