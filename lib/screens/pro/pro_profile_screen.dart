import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../services/pro_api.service.dart';

/// Profil professionnel — rempli par le professionnel lui-même après sa
/// première connexion. L'admin ne fait plus que créer la fiche + inviter ;
/// tout le reste (bio, spécialités, tarif, ville...) est en libre-service ici.
class ProProfileScreen extends StatefulWidget {
  const ProProfileScreen({super.key});

  @override
  State<ProProfileScreen> createState() => _ProProfileScreenState();
}

class _ProProfileScreenState extends State<ProProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController(); // séparées par des virgules
  final _priceCtrl = TextEditingController();

  String _type = 'psychologist';
  bool _isOnline = true;
  bool _isInPerson = true;

  // ⚠️ Anciennement une carte figée en dur ('psychologist'/'coach'/'doctor'
  // uniquement) — déconnectée des types réellement configurés en base.
  // Chargée maintenant depuis /professionals/me/types.
  List<Map<String, dynamic>> _types = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _specialtiesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!await ProApiService().isLoggedIn()) {
      if (mounted) context.go('/pro/login');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        ProApiService().getMe(),
        ProApiService().getProfessionalTypes(),
      ]);
      final me = results[0] as Map<String, dynamic>;
      final pro = me['professional'] as Map<String, dynamic>;
      _types = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();
      _firstNameCtrl.text = pro['firstName'] ?? '';
      _lastNameCtrl.text = pro['lastName'] ?? '';
      _phoneCtrl.text = pro['phone'] ?? '';
      _whatsappCtrl.text = pro['whatsapp'] ?? '';
      _bioCtrl.text = pro['bio'] ?? '';
      _cityCtrl.text = pro['city'] ?? '';
      _specialtiesCtrl.text = (pro['specialties'] as List<dynamic>?)?.join(', ') ?? '';
      _priceCtrl.text = pro['sessionPrice']?.toString() ?? '';
      _type = pro['type'] ?? 'psychologist';
      _isOnline = pro['isOnline'] ?? true;
      _isInPerson = pro['isInPerson'] ?? true;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!await ProApiService().isLoggedIn() && mounted) {
        context.go('/pro/login');
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final specialties = _specialtiesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await ProApiService().updateProfile({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'specialties': specialties,
        'sessionPrice': int.tryParse(_priceCtrl.text.trim()),
        'type': _type,
        'isOnline': _isOnline,
        'isInPerson': _isInPerson,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profil mis à jour')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: AppRadius.lg, borderSide: const BorderSide(color: AppColors.divider)),
      );

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
        title: const Text('Mon profil', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: [
                      Text(
                        'Ces informations sont visibles par les testeurs qui cherchent un professionnel à contacter.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                      ),
                      const SizedBox(height: 20),

                      Row(children: [
                        Expanded(child: TextField(controller: _firstNameCtrl, decoration: _dec('Prénom'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _lastNameCtrl, decoration: _dec('Nom'))),
                      ]),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: _types.any((t) => t['id'] == _type) ? _type : null,
                        decoration: _dec('Profession'),
                        items: _types
                            .map((t) => DropdownMenuItem(value: t['id'] as String, child: Text('${t['emoji'] ?? ''} ${t['label']}'.trim())))
                            .toList(),
                        onChanged: (v) => setState(() => _type = v ?? _type),
                      ),
                      const SizedBox(height: 16),

                      TextField(controller: _bioCtrl, decoration: _dec('Présentation courte'), maxLines: 3, maxLength: 400),
                      const SizedBox(height: 8),

                      TextField(controller: _specialtiesCtrl, decoration: _dec('Spécialités (séparées par des virgules)')),
                      const SizedBox(height: 16),

                      TextField(controller: _cityCtrl, decoration: _dec('Ville')),
                      const SizedBox(height: 16),

                      Row(children: [
                        Expanded(child: TextField(controller: _phoneCtrl, decoration: _dec('Téléphone'), keyboardType: TextInputType.phone)),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _whatsappCtrl, decoration: _dec('WhatsApp'), keyboardType: TextInputType.phone)),
                      ]),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _priceCtrl,
                        decoration: _dec('Tarif par séance (FCFA)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Consultations en ligne', style: AppTextStyles.body),
                        value: _isOnline,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isOnline = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Consultations en présentiel', style: AppTextStyles.body),
                        value: _isInPerson,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isInPerson = v),
                      ),

                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Enregistrer'),
                      ),
                    ],
                  ),
      ),
    );
  }
}