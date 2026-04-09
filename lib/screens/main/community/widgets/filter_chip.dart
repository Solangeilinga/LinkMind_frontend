import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';

class FilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  
  const FilterChip({
    super.key,
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
        borderRadius: AppRadius.full,
        border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5)),
      child: Text('$emoji $label', style: AppTextStyles.caption.copyWith(
        color: isSelected ? color : AppColors.onSurfaceMuted,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600)),
    ),
  );
}