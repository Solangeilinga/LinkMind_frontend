import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../services/pro_api.service.dart';

class ProSetupPasswordScreen extends StatefulWidget {
  final String? token;
  const ProSetupPasswordScreen({super.key, this.token});

  @override
  State<ProSetupPasswordScreen> createState() => _ProSetupPasswordScreenState();
}

class _ProSetupPasswordScreenState extends State<ProSetupPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() => _error = 'Lien invalide. Demande un nouveau lien à l\'équipe BASYAM.');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _error = 'Le mot de passe doit faire au moins 8 caractères.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await ProApiService().setupPassword(widget.token!, _passwordController.text);
      if (mounted) context.go('/pro/dashboard');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                Center(child: Image.asset('assets/images/logo.png', height: 72)),
                const SizedBox(height: 20),
                const Text('Bienvenue', style: AppTextStyles.h1, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  'Choisis un mot de passe pour accéder à ton espace professionnel BASYAM.',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: AppRadius.lg, borderSide: const BorderSide(color: AppColors.divider)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Confirme le mot de passe',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: AppRadius.lg, borderSide: const BorderSide(color: AppColors.divider)),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: AppRadius.md),
                    child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
                  ),
                ],

                const SizedBox(height: 24),
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
                      : const Text('Activer mon compte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
