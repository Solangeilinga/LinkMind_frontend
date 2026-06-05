class CompletionTypeConfig {
  final String type; // 'timer', 'action', 'reflection', 'social', 'exploration'
  final Map<String, dynamic> config;

  CompletionTypeConfig({required this.type, required this.config});

  factory CompletionTypeConfig.fromJson(Map<String, dynamic> json) {
    // 🔥 CORRECTION : Gérer les cas où config est null ou pas du bon type
    Map<String, dynamic> safeConfig = {};
    final configValue = json['config'];
    if (configValue is Map) {
      safeConfig = Map<String, dynamic>.from(configValue);
    }
    
    return CompletionTypeConfig(
      type: json['type']?.toString() ?? 'action',
      config: safeConfig,
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
    // 🔥 CORRECTION : Convertir chaque champ avec .toString() pour éviter les casts dynamiques
    return Challenge(
      id: (json['_id'] ?? json['id']).toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      instructions: _toStringList(json['instructions']),
      category: json['category']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? 'easy',
      durationMinutes: _toInt(json['durationMinutes']),
      points: _toInt(json['points']),
      icon: json['icon']?.toString() ?? '⚡',
      completionType: CompletionTypeConfig.fromJson(
        json['completionType'] is Map ? Map<String, dynamic>.from(json['completionType']) : {'type': 'action', 'config': {}}
      ),
      targetMoods: _toStringList(json['targetMoods']),
      requiredLevel: json['requiredLevel']?.toString() ?? 'all',
      isPremium: json['isPremium'] == true,
      isActive: json['isActive'] != false,
      order: _toInt(json['order']),
      isCompleted: json['isCompleted'] == true,
    );
  }
}

// 🔥 Fonctions utilitaires pour convertir les valeurs de manière sûre
List<String> _toStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value.map((e) => e?.toString() ?? '').toList();
  }
  return [];
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}