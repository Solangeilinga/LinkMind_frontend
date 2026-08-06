import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utils/theme.dart';
import '../../utils/icon_mapper.dart';
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
  bool _isLoadingOperators = false;
  String? _error;
  String _selectedPlan = 'monthly';
  String _selectedCountry = 'BF';
  String? _selectedOperatorSlug;
  bool _otpRequired = false;
  String? _ussdCode;
  List<dynamic> _operators = [];
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  Map<String, dynamic>? _userStatus;

  // Pays pris en charge par SebPay (Afrique de l'Ouest/Centrale francophone).
  // BF (Burkina Faso) présélectionné car c'est le marché principal de BASYAM.
  static const List<Map<String, String>> _countries = [
    {'code': 'BF', 'name': 'Burkina Faso'},
    {'code': 'CI', 'name': 'Côte d\'Ivoire'},
    {'code': 'SN', 'name': 'Sénégal'},
    {'code': 'BJ', 'name': 'Bénin'},
    {'code': 'TG', 'name': 'Togo'},
    {'code': 'ML', 'name': 'Mali'},
    {'code': 'NE', 'name': 'Niger'},
    {'code': 'GN', 'name': 'Guinée'},
    {'code': 'CM', 'name': 'Cameroun'},
    {'code': 'GA', 'name': 'Gabon'},
    {'code': 'TD', 'name': 'Tchad'},
    {'code': 'CD', 'name': 'RD Congo'},
  ];

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
    _fetchOperators();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _fetchOperators() async {
    setState(() {
      _isLoadingOperators = true;
      _selectedOperatorSlug = null;
      _otpRequired = false;
      _ussdCode = null;
    });
    try {
      final response = await ApiService().get(
        '/payment/operators',
        queryParams: {'country': _selectedCountry},
        forceRefresh: true, // ne jamais servir une liste d'opérateurs périmée en cache
      );
      if (mounted) {
        setState(() {
          _operators = (response['operators'] as List<dynamic>?) ?? [];
          _isLoadingOperators = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _operators = [];
          _isLoadingOperators = false;
        });
      }
    }
  }

  void _onOperatorSelected(Map<String, dynamic> operator) {
    setState(() {
      _selectedOperatorSlug = operator['slug'] as String?;
      _otpRequired = operator['otp_required'] == true;
      _ussdCode = operator['ussd_code'] as String?;
    });
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
    if (_selectedOperatorSlug == null) {
      setState(() => _error = 'Choisis ton opérateur Mobile Money.');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Entre ton numéro de téléphone.');
      return;
    }
    if (_otpRequired && _otpController.text.trim().isEmpty) {
      setState(() => _error = 'Entre le code reçu par USSD.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService().post('/payment/initiate', {
        'plan': _selectedPlan,
        'phone': _phoneController.text.trim(),
        'operatorSlug': _selectedOperatorSlug,
        'countryCode': _selectedCountry,
        if (_otpRequired) 'otpCode': _otpController.text.trim(),
      });

      if (mounted) {
        final transactionId = response['transactionId'] as String?;
        if (transactionId == null) {
          setState(() {
            _error = 'Erreur d\'initiation du paiement';
            _isLoading = false;
          });
          return;
        }

        if (response['providerLink'] != null) {
          // Cas Wave & consorts : redirection nécessaire vers une page de
          // validation externe.
          await _openPaymentWebView(
            response['providerLink'] as String,
            transactionId,
          );
        } else {
          // Cas standard (Orange Money, MTN, Moov...) : le client valide
          // directement sur son téléphone via USSD, on attend juste la
          // confirmation du webhook signé.
          setState(() => _isLoading = false);
          _checkPaymentStatus(transactionId);
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
    String transactionId,
  ) async {
    setState(() => _isLoading = false);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentWebView(
          url: url,
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
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
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
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
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
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                const Text('Vérifie ton téléphone 📲', style: AppTextStyles.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Une demande de validation vient de t\'être envoyée par USSD. Confirme le paiement sur ton téléphone.',
                  style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
            Center(
              child: Column(
                children: [
                  IconMapper.getIcon('👑', size: 56, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text('Débloque tout le potentiel de BASYAM',
                      style: AppTextStyles.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
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
                  _PremiumFeature(emoji: '⭐', title: 'Accès prioritaire aux professionnels', description: 'priorité sur les rendez-vous'),
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
              // Choix du pays
              const Text('Ton pays', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountry,
                    isExpanded: true,
                    items: _countries
                        .map((c) => DropdownMenuItem(
                              value: c['code'],
                              child: Text(c['name']!),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedCountry = value);
                      _fetchOperators();
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Choix de l'opérateur (récupéré dynamiquement depuis SebPay)
              const Text('Opérateur Mobile Money', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              if (_isLoadingOperators)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_operators.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.md,
                  ),
                  child: const Text(
                    'Aucun opérateur disponible pour ce pays pour le moment.',
                    style: AppTextStyles.caption,
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _operators.map((op) {
                    final operator = op as Map<String, dynamic>;
                    final isSelected = _selectedOperatorSlug == operator['slug'];
                    return GestureDetector(
                      onTap: () => _onOperatorSelected(operator),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surfaceVariant,
                          borderRadius: AppRadius.full,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          (operator['name'] as String?) ?? '',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 20),

              // Numéro de téléphone
              const Text('Numéro de téléphone', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Ex : 70123456',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.lg,
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),

              // Champ OTP conditionnel selon l'opérateur sélectionné
              if (_otpRequired) ...[
                const SizedBox(height: 20),
                if (_ussdCode != null && _ussdCode!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.md,
                    ),
                    child: Text(
                      'Compose $_ussdCode sur ton téléphone pour obtenir le code de validation.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                const Text('Code de validation', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Code reçu par USSD',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.lg,
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                  ),
                ),
              ],

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
                                IconMapper.getIcon(data['emoji'] as String, size: 28, color: AppColors.primary),
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
                'Paiement sécurisé par SebPay',
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
          IconMapper.getIcon(emoji, size: 22, color: AppColors.primary),
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
      decoration: const BoxDecoration(
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
  final String transactionId;
  final Function(bool) onComplete;

  const PaymentWebView({
    super.key,
    required this.url,
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


// ─── Contact support premium ──────────────────────────────────────────────────
class _PremiumContactSection extends StatelessWidget {
  const _PremiumContactSection();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.lg,
        ),
        child: Column(children: [
          Text('Un problème avec le paiement ?',
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Notre équipe répond dans les 24h',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(
                    'https://wa.me/22600000000?text=Bonjour%2C%20j%27ai%20un%20probl%C3%A8me%20avec%20mon%20abonnement%20BASYAM%20Premium.');
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
              icon: const Text('💬', style: TextStyle(fontSize: 16)),
              label: const Text('Écrire sur WhatsApp'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.divider),
              ),
            ),
          ]),
        ]),
      );
}