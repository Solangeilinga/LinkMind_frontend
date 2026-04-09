import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utils/theme.dart';
import '../../services/api.service.dart';
import '../../providers/auth_provider.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _isLoading = false;
  bool _isChecking = false;
  String? _error;
  String _selectedProvider = 'cinetpay';
  String _selectedPlan = 'monthly';
  Map<String, dynamic>? _userStatus;

  static const Map<String, Map<String, dynamic>> _providers = {
    'cinetpay': {'name': 'CinetPay', 'emoji': '💳', 'color': AppColors.primary},
    'orange': {'name': 'Orange Money', 'emoji': '📱', 'color': Color(0xFFFF6600)},
  };

  static const Map<String, Map<String, dynamic>> _plans = {
    'monthly': {
      'name': 'Mensuel',
      'price': 5000,
      'priceLabel': '5 000 FCFA',
      'days': 30,
      'emoji': '📅',
      'popular': false,
    },
    'yearly': {
      'name': 'Annuel',
      'price': 50000,
      'priceLabel': '50 000 FCFA',
      'days': 365,
      'emoji': '🎯',
      'saving': 'Économise 10 000 FCFA',
      'popular': true,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
  }

  Future<void> _loadUserStatus() async {
    try {
      final status = await ApiService().get('/payment/status');
      if (mounted) {
        setState(() => _userStatus = status);
      }
    } catch (_) {}
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plan = _plans[_selectedPlan]!;
      final response = await ApiService().post('/payment/initiate', {
        'provider': _selectedProvider,
        'amount': plan['price'],
        'plan': _selectedPlan,
      });

      if (mounted) {
        if (response['paymentUrl'] != null) {
          await _openPaymentWebView(
            response['paymentUrl'] as String,
            response['paymentData'] as Map<String, dynamic>?,
            response['transactionId'] as String,
          );
        } else {
          setState(() {
            _error = 'Erreur d\'initiation du paiement';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openPaymentWebView(
    String url,
    Map<String, dynamic>? paymentData,
    String transactionId,
  ) async {
    setState(() => _isLoading = false);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentWebView(
          url: url,
          paymentData: paymentData,
          transactionId: transactionId,
          onComplete: (success) {
            if (success) {
              _checkPaymentStatus(transactionId);
            }
          },
        ),
      ),
    );

    if (result == true) {
      _checkPaymentStatus(transactionId);
    }
  }

  Future<void> _checkPaymentStatus(String transactionId) async {
    setState(() => _isChecking = true);

    await Future.delayed(const Duration(seconds: 3));

    for (int i = 0; i < 5; i++) {
      try {
        final status = await ApiService().get('/payment/status');
        if (status['isPremium'] == true) {
          await ref.read(authProvider.notifier).refreshUser();
          if (mounted) {
            setState(() => _isChecking = false);
            _showSuccessDialog();
          }
          return;
        }
      } catch (_) {}

      if (i < 4) await Future.delayed(const Duration(seconds: 2));
    }

    if (mounted) {
      setState(() => _isChecking = false);
      _showPendingDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.secondary, size: 32),
            SizedBox(width: 12),
            Text('Félicitations !'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tu es maintenant membre Premium !'),
            SizedBox(height: 12),
            Text('Profite de toutes les fonctionnalités exclusives.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/profile');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('Paiement en cours'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            SizedBox(height: 16),
            Text('Ton paiement est en cours de traitement.'),
            SizedBox(height: 8),
            Text('Tu recevras une confirmation par email.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/profile');
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlreadyPremium = _userStatus?['isPremium'] == true;

    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Vérification du paiement...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Passer en Premium'),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Center(
              child: Column(
                children: [
                  Text('👑', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 8),
                  Text('Débloque tout le potentiel de LinkMind',
                      style: AppTextStyles.h2, textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text('Accède à toutes les fonctionnalités Premium',
                      style: AppTextStyles.body, textAlign: TextAlign.center),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Avantages Premium
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✨ Ce que tu obtiens', style: AppTextStyles.h3),
                  SizedBox(height: 16),
                  _PremiumFeature(emoji: '🧠', title: 'Mindo illimité', description: 'Plus de limite de 10 messages par jour'),
                  _PremiumFeature(emoji: '📊', title: 'Rapports PDF détaillés', description: 'Exporte ton évolution en PDF'),
                  _PremiumFeature(emoji: '🚫', title: 'Sans publicités', description: 'Navigation sans interruptions'),
                  _PremiumFeature(emoji: '🎁', title: 'Contenu exclusif', description: 'Défis et contenus Premium'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (isAlreadyPremium)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.secondary),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.secondary),
                    SizedBox(width: 12),
                    Expanded(child: Text('Tu es déjà Premium !')),
                  ],
                ),
              )
            else ...[
              // Choix du fournisseur
              const Text('Moyen de paiement', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              Row(
                children: _providers.keys.map((provider) {
                  final data = _providers[provider]!;
                  final isSelected = _selectedProvider == provider;
                  final color = data['color'] as Color;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedProvider = provider),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.1)
                              : AppColors.surfaceVariant,
                          borderRadius: AppRadius.md,
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(data['emoji'] as String, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 4),
                            Text(
                              data['name'] as String,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Choix du plan
              const Text('Choisis ton offre', style: AppTextStyles.h3),
              const SizedBox(height: 12),

              Row(
                children: _plans.keys.map((plan) {
                  final data = _plans[plan]!;
                  final isSelected = _selectedPlan == plan;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlan = plan),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surface,
                          borderRadius: AppRadius.lg,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.divider,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                Text(data['emoji'] as String, style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 8),
                                Text(data['name'] as String, style: AppTextStyles.h4),
                                const SizedBox(height: 4),
                                Text(
                                  data['priceLabel'] as String,
                                  style: AppTextStyles.h2.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 20,
                                  ),
                                ),
                                if (data['saving'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      data['saving'] as String,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (data['popular'] == true)
                              const Positioned(
                                top: -8,
                                right: -8,
                                child: _PopularBadge(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: AppTextStyles.bodySmall)),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isAlreadyPremium ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Je passe Premium', style: AppTextStyles.button),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: Text(
                'Paiement sécurisé par ${_providers[_selectedProvider]!['name']}',
                style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─── Premium Feature Widget ───────────────────────────────────────────────────
class _PremiumFeature extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;

  const _PremiumFeature({
    required this.emoji,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
                Text(description, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Popular Badge ────────────────────────────────────────────────────────────
class _PopularBadge extends StatelessWidget {
  const _PopularBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: AppRadius.full,
      ),
      child: const Text(
        'POPULAIRE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── WebView pour le paiement ─────────────────────────────────────────────────
class PaymentWebView extends StatefulWidget {
  final String url;
  final Map<String, dynamic>? paymentData;
  final String transactionId;
  final Function(bool) onComplete;

  const PaymentWebView({
    super.key,
    required this.url,
    this.paymentData,
    required this.transactionId,
    required this.onComplete,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            if (url.contains('return_url') || url.contains('success')) {
              widget.onComplete(true);
              if (mounted) Navigator.pop(context, true);
            }
            if (url.contains('cancel') || url.contains('error')) {
              widget.onComplete(false);
              if (mounted) Navigator.pop(context, false);
            }
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onComplete(false);
            Navigator.pop(context, false);
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}