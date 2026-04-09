class CompletionTypeConfig {
  final String type; // 'timer', 'action', 'reflection', 'social', 'exploration'
  final Map<String, dynamic> config;

  CompletionTypeConfig({required this.type, required this.config});

  factory CompletionTypeConfig.fromJson(Map<String, dynamic> json) {
    return CompletionTypeConfig(
      type: json['type'] as String,
      config: json['config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'config': config,
  };
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final List<String> instructions;
  final String category;
  final String difficulty;
  final int durationMinutes;
  final int points;
  final String icon;
  final CompletionTypeConfig completionType;
  final List<String> targetMoods;
  final String requiredLevel;
  final bool isPremium;
  final bool isActive;
  final int order;
  final bool isCompleted;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.category,
    required this.difficulty,
    required this.durationMinutes,
    required this.points,
    required this.icon,
    required this.completionType,
    required this.targetMoods,
    required this.requiredLevel,
    required this.isPremium,
    required this.isActive,
    required this.order,
    this.isCompleted = false,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      instructions: List<String>.from(json['instructions'] ?? []),
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? 'easy',
      durationMinutes: json['durationMinutes'] ?? 0,
      points: json['points'] ?? 0,
      icon: json['icon'] ?? '⚡',
      completionType: CompletionTypeConfig.fromJson(json['completionType'] ?? {'type': 'action', 'config': {}}),
      targetMoods: List<String>.from(json['targetMoods'] ?? []),
      requiredLevel: json['requiredLevel'] ?? 'all',
      isPremium: json['isPremium'] ?? false,
      isActive: json['isActive'] ?? true,
      order: json['order'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}