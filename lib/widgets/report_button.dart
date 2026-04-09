import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/api.service.dart';

enum ReportReason {
  spam('Spam', 'Contenu promotionnel non sollicité'),
  harassment('Harcèlement', 'Attaques personnelles ou intimidation'),
  hateSpeech('Discours haineux', 'Contenu discriminatoire ou haineux'),
  violence('Violence', 'Incitation à la violence ou contenu violent'),
  inappropriate('Contenu inapproprié', 'Contenu choquant ou dérangeant'),
  other('Autre', 'Autre raison');

  final String label;
  final String description;
  const ReportReason(this.label, this.description);
}

class ReportButton extends StatefulWidget {
  final String targetType;
  final String targetId;
  final VoidCallback? onReported;
  final bool isSmall;

  const ReportButton({
    super.key,
    required this.targetType,
    required this.targetId,
    this.onReported,
    this.isSmall = false,
  });

  @override
  State<ReportButton> createState() => _ReportButtonState();
}

class _ReportButtonState extends State<ReportButton> {
  bool _isReporting = false;
  ReportReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.accent : AppColors.secondary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitReport(BuildContext dialogContext) async {
    if (_selectedReason == null) return;
    
    setState(() => _isReporting = true);
    try {
      final response = await ApiService().post(
        '/community/${widget.targetType}s/${widget.targetId}/report',
        {
          'reason': _selectedReason!.name,
          'details': _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
        },
      );
      
      // Fermer le dialog
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      
      // Message de succès
      if (response['autoHidden'] == true) {
        _showMessage('⚠️ Signalement pris en compte. Contenu masqué automatiquement.');
      } else {
        _showMessage('✅ Signalement pris en compte. Merci !');
      }
      
      widget.onReported?.call();
      
    } catch (e) {
      // Fermer le dialog
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      
      // Analyser l'erreur
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('409') || errorStr.contains('already reported')) {
        _showMessage('⚠️ Vous avez déjà signalé ce contenu.', isError: false);
      } 
      else if (errorStr.contains('429')) {
        _showMessage('⏳ Trop de signalements. Veuillez patienter.', isError: true);
      }
      else if (errorStr.contains('403')) {
        _showMessage('🔒 Action non autorisée.', isError: true);
      }
      else {
        _showMessage('❌ Erreur lors du signalement. Réessayez plus tard.', isError: true);
      }
      
    } finally {
      if (mounted) setState(() => _isReporting = false);
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Signaler'),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pourquoi signalez-vous ce contenu ?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...ReportReason.values.map((reason) => RadioListTile<ReportReason>(
                    title: Text(reason.label, style: AppTextStyles.bodySmall),
                    subtitle: Text(reason.description, style: AppTextStyles.caption),
                    value: reason,
                    groupValue: _selectedReason,
                    onChanged: (value) {
                      setState(() => _selectedReason = value);
                      setDialogState(() {});
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
                  if (_selectedReason == ReportReason.other) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _detailsController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Précisez votre signalement...',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: AppRadius.md,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Votre signalement est anonyme et sera examiné par notre équipe.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: _selectedReason != null 
                    ? () => _submitReport(dialogContext)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(80, 36),
                ),
                child: _isReporting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Signaler'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.flag_outlined, 
        size: widget.isSmall ? 16 : 18,
        color: AppColors.onSurfaceMuted,
      ),
      tooltip: 'Signaler',
      onPressed: _showReportDialog,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: widget.isSmall ? 24 : 32,
        minHeight: widget.isSmall ? 24 : 32,
      ),
      splashRadius: widget.isSmall ? 16 : 20,
    );
  }
}