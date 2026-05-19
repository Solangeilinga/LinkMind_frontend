import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';

class MoodHistoryScreen extends ConsumerWidget {
  const MoodHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(moodProvider).history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique de l\'humeur'),
        leading: const BackButton(),
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📊', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('Pas encore d\'historique',
                      style: AppTextStyles.h3, textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text('Enregistre ton humeur chaque jour\npour voir ton évolution.',
                      style: AppTextStyles.body, textAlign: TextAlign.center),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: history.length,
              itemBuilder: (context, i) {
                final entry = history[history.length - 1 - i]; // Most recent first
                final score = entry['score'] as int? ?? 3;
                final label = entry['label'] as String? ?? 'neutral';
                final date = DateTime.tryParse(entry['createdAt']?.toString() ?? '');

                final moodDef = kMoods.firstWhere(
                  (m) => m.id == label, orElse: () => kMoods[2]);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.md,
                    border: Border.all(color: moodDef.color.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: moodDef.color.withValues(alpha: 0.15),
                          borderRadius: AppRadius.md,
                        ),
                        child: Center(
                          child: Text(moodDef.emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(moodDef.label,
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
                            if (entry['note'] != null)
                              Text(entry['note'],
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.onSurfaceMuted),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: List.generate(5, (s) => Icon(
                              s < score ? Icons.circle : Icons.circle_outlined,
                              size: 8,
                              color: s < score ? moodDef.color : AppColors.divider,
                            )),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date != null ? _formatDate(date) : '',
                            style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    return 'Il y a $diff jours';
  }
}