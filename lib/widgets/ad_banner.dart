import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../services/api.service.dart';

class AdBanner extends StatefulWidget {
  final String placement;
  const AdBanner({super.key, required this.placement});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  Map<String, dynamic>? _ad;
  bool _loading  = true;
  bool _dismissed = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await ApiService().get('/ads',
          queryParams: {'placement': widget.placement});
      if (mounted) setState(() {
        _ad      = data['ad'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trackClick(String adId) async {
    try { await ApiService().post('/ads/$adId/click', {}); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _ad == null || _dismissed) return const SizedBox.shrink();

    final ad       = _ad!;
    final adId     = (ad['_id'] ?? '').toString();
    final emoji    = ad['emoji'] as String? ?? '🌿';
    final title    = ad['title'] as String? ?? '';
    final desc     = ad['description'] as String? ?? '';
    final ctaLabel = ad['ctaLabel'] as String? ?? 'En savoir plus';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label sponsorisé + bouton fermer
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Text('Sponsorisé',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 10, fontStyle: FontStyle.italic)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: const Icon(Icons.close, size: 14, color: AppColors.onSurfaceMuted)),
          ]),
        ),

        // Contenu
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: AppRadius.md),
              child: Center(child: Text(emoji,
                  style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w800)),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(desc,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceMuted, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ])),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _trackClick(adId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: AppRadius.full),
                child: Text(ctaLabel,
                    style: AppTextStyles.caption.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}