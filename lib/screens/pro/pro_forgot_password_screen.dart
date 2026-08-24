import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../services/pro_api.service.dart';

class ProForgotPasswordScreen extends StatefulWidget {
  const ProForgotPasswordScreen({super.key});

  @override
  State<ProForgotPasswordScreen> createState() => _ProForgotPasswordScreenState();
}

class _ProForgotPasswordScreenState extends State<ProForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ProApiService().forgotPassword(_emailController.text.trim());
    } catch (_) {
      // Le backend répond toujours avec succès (anti-énumération) — on
      // affiche le même message quoi qu'il arrive.
    } finally {
      if (mounted) setState(() { _isLoading = false; _sent = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  onPressed: () => context.pop(),
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 8),
                const Text('Mot de passe oublié', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'Entre ton email professionnel, on t\'envoie un lien pour en choisir un nouveau.',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                ),
                const SizedBox(height: 24),

                if (_sent) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: AppRadius.lg,
                    ),
                    child: const Text(
                      'Si un compte professionnel existe avec cet email, un lien de réinitialisation vient d\'être envoyé. Vérifie ta boîte de réception (et tes spams).',
                      style: AppTextStyles.body,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => context.go('/pro/login'),
                    child: const Text('Retour à la connexion'),
                  ),
                ] else ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Email professionnel',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: AppRadius.lg, borderSide: const BorderSide(color: AppColors.divider)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Envoyer le lien'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
