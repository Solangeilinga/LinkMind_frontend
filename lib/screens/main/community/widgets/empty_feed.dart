import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';

class EmptyFeed extends StatelessWidget {
  final VoidCallback onCompose;
  final String message;
  
  const EmptyFeed({
    super.key,
    required this.onCompose,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🌱', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(message, style: AppTextStyles.h4, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text("Sois le premier à partager.",
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onCompose,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Partager'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(160, 42))),
          ]),
        ),
      ),
    ),
  );
}