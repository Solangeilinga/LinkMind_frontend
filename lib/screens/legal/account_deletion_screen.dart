import 'package:flutter/material.dart';
import '../../services/api.service.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';

// Page publique (accessible sans connexion, y compris sur le web à l'adresse
// /legal/account-deletion) permettant de demander la suppression de son
// compte sans avoir accès à l'application. Exigée par Google Play.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _emailCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (!Validators.isValidEmail(email)) {
      setState(() => _error = 'Saisis une adresse email valide.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final reason = _reasonCtrl.text.trim();
      await ApiService().post('/auth/request-account-deletion', {
        'email': email,
        if (reason.isNotEmpty) 'reason': reason,
      });
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Impossible d\'envoyer la demande pour le moment. Réessaie dans quelques minutes ou écris à support@basyam.com.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _card({required Widget child, Color? color, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: borderColor ?? AppColors.divider),
      ),
      child: child,
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text, style: AppTextStyles.body.copyWith(height: 1.4))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Suppression de compte'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Supprimer mon compte BASYAM', style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  Text(
                    'Tu peux demander la suppression de ton compte et de tes données, même si tu n\'as plus accès à l\'application.',
                    style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ce qui est supprimé', style: AppTextStyles.h4),
                        const SizedBox(height: 10),
                        _bullet('Ton compte et les informations de ton profil'),
                        _bullet('Tes humeurs, notes, défis, points et badges'),
                        _bullet('Tes publications dans la communauté sont anonymisées, c\'est-à-dire détachées de ton compte'),
                        const SizedBox(height: 4),
                        Text(
                          'Tes données sont supprimées dans un délai maximum de 30 jours. Une copie peut subsister brièvement dans une sauvegarde avant d\'être définitivement effacée.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Option 1 : depuis l\'application', style: AppTextStyles.h4),
                        const SizedBox(height: 8),
                        Text(
                          'Ouvre Profil, puis Paramètres, puis « Supprimer mon compte ». La suppression est immédiate.',
                          style: AppTextStyles.body.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_sent)
                    _card(
                      color: AppColors.secondary.withValues(alpha: 0.08),
                      borderColor: AppColors.secondary.withValues(alpha: 0.4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Demande envoyée. Si un compte existe avec cet email, ta demande a bien été transmise à notre équipe. Elle sera traitée sous 30 jours maximum.',
                              style: AppTextStyles.body.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Option 2 : sans accès à l\'application', style: AppTextStyles.h4),
                          const SizedBox(height: 6),
                          Text(
                            'Saisis l\'adresse email de ton compte. Pour ta sécurité, la réponse est la même que cet email corresponde ou non à un compte.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email du compte *',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _reasonCtrl,
                            maxLines: 3,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              labelText: 'Raison (optionnel)',
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _sending ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppColors.primary,
                              ),
                              child: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text('Envoyer ma demande',
                                      style: AppTextStyles.button.copyWith(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Une question ? Écris-nous à support@basyam.com.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
