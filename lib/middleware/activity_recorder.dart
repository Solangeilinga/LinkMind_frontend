import 'package:flutter/material.dart';
import '../services/security.service.dart';

/// Widget pour enregistrer automatiquement les activités
class ActivityRecorder extends StatelessWidget {
  final Widget child;
  final String activityType;
  final Map<String, dynamic>? metadata;

  const ActivityRecorder({
    super.key,
    required this.child,
    required this.activityType,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _recordActivity(),
      onLongPress: () => _recordActivity(),
      child: child,
    );
  }

  void _recordActivity() {
    SecurityService.recordActivity(
      type: activityType,
      metadata: metadata,
    );
  }
}