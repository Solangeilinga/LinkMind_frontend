// ============================================================================
// FICHIER: lib/models/user_model.dart
// ============================================================================

// ─── Fonctions utilitaires pour la sécurité des types ──────────────────────
String _safeString(Map<String, dynamic> json, String key, [String defaultValue = '']) {
  final value = json[key];
  if (value == null) return defaultValue;
  return value.toString();
}

int _safeInt(Map<String, dynamic> json, String key, [int defaultValue = 0]) {
  final value = json[key];
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

bool _safeBool(Map<String, dynamic> json, String key, [bool defaultValue = false]) {
  final value = json[key];
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return defaultValue;
}

String? _safeStringNullable(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return value.toString();
}

List<String> _safeStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return [];
  if (value is List) {
    return value.map((e) => e?.toString() ?? '').toList();
  }
  return [];
}

List<UserBadge> _safeBadgeList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return [];
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map((b) => UserBadge.fromJson(b))
        .toList();
  }
  return [];
}

// ─── UserModel ───────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String name;
  final String? firstName;
  final String? lastName;
  final String? email;
  final int? age;
  final String? city;
  final String? country;
  final String? gender;
  final String? avatar;
  final String? anonymousAlias;
  final int totalPoints;
  final String level;
  final int streakDays;
  final bool isPremium;
  final bool isEmailVerified;
  final bool legalAccepted;
  final UserPreferences preferences;
  final List<UserBadge> badges;

  const UserModel({
    required this.id,
    required this.name,
    this.firstName,
    this.lastName,
    this.email,
    this.age,
    this.city,
    this.country,
    this.gender,
    this.avatar,
    this.anonymousAlias,
    required this.totalPoints,
    required this.level,
    required this.streakDays,
    required this.isPremium,
    this.isEmailVerified = false,
    this.legalAccepted = false,
    required this.preferences,
    this.badges = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // 🔒 Extraction sécurisée des données
    final userData = json;
    
    // Si le JSON contient une clé 'data', l'utiliser
    final data = userData.containsKey('data') && userData['data'] is Map
        ? Map<String, dynamic>.from(userData['data'])
        : userData;

    // Si le JSON contient une clé 'user', l'utiliser
    final user = data.containsKey('user') && data['user'] is Map
        ? Map<String, dynamic>.from(data['user'])
        : data;

    return UserModel(
      id: _safeString(user, 'id', _safeString(user, '_id', '')),
      name: _safeString(user, 'name'),
      firstName: _safeStringNullable(user, 'firstName'),
      lastName: _safeStringNullable(user, 'lastName'),
      email: _safeStringNullable(user, 'email'),
      age: _safeInt(user, 'age'),
      city: _safeStringNullable(user, 'city'),
      country: _safeStringNullable(user, 'country'),
      gender: _safeStringNullable(user, 'gender'),
      avatar: _safeStringNullable(user, 'avatar'),
      anonymousAlias: _safeStringNullable(user, 'anonymousAlias'),
      totalPoints: _safeInt(user, 'totalPoints'),
      level: _safeString(user, 'level', 'bronze'),
      streakDays: _safeInt(user, 'streakDays'),
      isPremium: _safeBool(user, 'isPremium'),
      isEmailVerified: _safeBool(user, 'isEmailVerified'),
      legalAccepted: _safeBool(user, 'legalAccepted'),
      preferences: user.containsKey('preferences') && user['preferences'] is Map
          ? UserPreferences.fromJson(Map<String, dynamic>.from(user['preferences']))
          : const UserPreferences(),
      badges: _safeBadgeList(user, 'badges'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'age': age,
    'city': city,
    'country': country,
    'gender': gender,
    'avatar': avatar,
    'anonymousAlias': anonymousAlias,
    'totalPoints': totalPoints,
    'level': level,
    'streakDays': streakDays,
    'isPremium': isPremium,
    'isEmailVerified': isEmailVerified,
    'legalAccepted': legalAccepted,
    'preferences': preferences.toJson(),
    'badges': badges.map((b) => b.toJson()).toList(),
  };

  int get levelProgress {
    switch (level) {
      case 'bronze': return (totalPoints / 300 * 100).clamp(0, 100).toInt();
      case 'silver': return ((totalPoints - 300) / 500 * 100).clamp(0, 100).toInt();
      case 'gold': return ((totalPoints - 800) / 1200 * 100).clamp(0, 100).toInt();
      default: return 100;
    }
  }

  String get levelLabel {
    const labels = {'bronze': 'Bronze', 'silver': 'Argent', 'gold': 'Or', 'platinum': 'Platine'};
    return labels[level] ?? 'Bronze';
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? firstName,
    String? lastName,
    String? email,
    int? age,
    String? city,
    String? country,
    String? gender,
    String? avatar,
    String? anonymousAlias,
    int? totalPoints,
    String? level,
    int? streakDays,
    bool? isPremium,
    bool? isEmailVerified,
    bool? legalAccepted,
    UserPreferences? preferences,
    List<UserBadge>? badges,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      age: age ?? this.age,
      city: city ?? this.city,
      country: country ?? this.country,
      gender: gender ?? this.gender,
      avatar: avatar ?? this.avatar,
      anonymousAlias: anonymousAlias ?? this.anonymousAlias,
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      streakDays: streakDays ?? this.streakDays,
      isPremium: isPremium ?? this.isPremium,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      legalAccepted: legalAccepted ?? this.legalAccepted,
      preferences: preferences ?? this.preferences,
      badges: badges ?? this.badges,
    );
  }
}

// ─── UserPreferences ─────────────────────────────────────────────────────────
class UserPreferences {
  final bool notificationsEnabled;
  final String reminderTime;
  final bool anonymousInCommunity;
  final String theme;

  const UserPreferences({
    this.notificationsEnabled = true,
    this.reminderTime = '20:00',
    this.anonymousInCommunity = false,
    this.theme = 'auto',
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
    notificationsEnabled: _safeBool(json, 'notificationsEnabled', true),
    reminderTime: _safeString(json, 'reminderTime', '20:00'),
    anonymousInCommunity: _safeBool(json, 'anonymousInCommunity', false),
    theme: _safeString(json, 'theme', 'auto'),
  );

  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'reminderTime': reminderTime,
    'anonymousInCommunity': anonymousInCommunity,
    'theme': theme,
  };
}

// ─── UserBadge ──────────────────────────────────────────────────────────────
class UserBadge {
  final String badgeId;
  final DateTime? earnedAt;

  const UserBadge({required this.badgeId, this.earnedAt});

  factory UserBadge.fromJson(Map<String, dynamic> json) => UserBadge(
    badgeId: _safeString(json, 'badgeId', _safeString(json, 'id', '')),
    earnedAt: json['earnedAt'] != null 
        ? DateTime.tryParse(json['earnedAt'].toString()) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    'badgeId': badgeId,
    'earnedAt': earnedAt?.toIso8601String(),
  };
}

// ─── MoodEntry ──────────────────────────────────────────────────────────────
class MoodEntry {
  final String? id;
  final int? score;
  final String? label;
  final String? note;
  final List<String> factors;
  final int? energyLevel;
  final String date;
  final DateTime? recordedAt;

  const MoodEntry({
    this.id,
    this.score,
    this.label,
    this.note,
    this.factors = const [],
    this.energyLevel,
    required this.date,
    this.recordedAt,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
    id: _safeStringNullable(json, '_id') ?? _safeStringNullable(json, 'id'),
    score: _safeInt(json, 'score'),
    label: _safeStringNullable(json, 'label'),
    note: _safeStringNullable(json, 'note'),
    factors: _safeStringList(json, 'factors'),
    energyLevel: _safeInt(json, 'energyLevel'),
    date: _safeString(json, 'date'),
    recordedAt: json['recordedAt'] != null 
        ? DateTime.tryParse(json['recordedAt'].toString()) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'score': score,
    'label': label,
    'note': note,
    'factors': factors,
    'energyLevel': energyLevel,
    'date': date,
    if (recordedAt != null) 'recordedAt': recordedAt?.toIso8601String(),
  };
}

// ─── ChallengeModel ──────────────────────────────────────────────────────────
class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final List<String> instructions;
  final String category;
  final String difficulty;
  final int durationMinutes;
  final int points;
  final String icon;
  final List<String> targetMoods;
  final bool isPremium;
  final bool isCompleted;
  final String? reason;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    this.instructions = const [],
    required this.category,
    required this.difficulty,
    required this.durationMinutes,
    required this.points,
    required this.icon,
    this.targetMoods = const [],
    this.isPremium = false,
    this.isCompleted = false,
    this.reason,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) => ChallengeModel(
    id: _safeString(json, '_id', _safeString(json, 'id', '')),
    title: _safeString(json, 'title'),
    description: _safeString(json, 'description'),
    instructions: _safeStringList(json, 'instructions'),
    category: _safeString(json, 'category'),
    difficulty: _safeString(json, 'difficulty', 'easy'),
    durationMinutes: _safeInt(json, 'durationMinutes', 5),
    points: _safeInt(json, 'points', 10),
    icon: _safeString(json, 'icon', '⚡'),
    targetMoods: _safeStringList(json, 'targetMoods'),
    isPremium: _safeBool(json, 'isPremium'),
    isCompleted: _safeBool(json, 'isCompleted'),
    reason: _safeStringNullable(json, 'reason'),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'description': description,
    'instructions': instructions,
    'category': category,
    'difficulty': difficulty,
    'durationMinutes': durationMinutes,
    'points': points,
    'icon': icon,
    'targetMoods': targetMoods,
    'isPremium': isPremium,
    'isCompleted': isCompleted,
    'reason': reason,
  };
}

// ─── PostModel ──────────────────────────────────────────────────────────────
class PostModel {
  final String id;
  final Map<String, dynamic>? author;
  final String content;
  final String postType;
  final int? moodScore;
  final bool isAnonymous;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    this.author,
    required this.content,
    required this.postType,
    this.moodScore,
    required this.isAnonymous,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
    id: _safeString(json, '_id', _safeString(json, 'id', '')),
    author: json['author'] is Map ? Map<String, dynamic>.from(json['author']) : null,
    content: _safeString(json, 'content'),
    postType: _safeString(json, 'postType', 'general'),
    moodScore: _safeInt(json, 'moodScore'),
    isAnonymous: _safeBool(json, 'isAnonymous'),
    likesCount: _safeInt(json, 'likesCount'),
    commentsCount: _safeInt(json, 'commentsCount'),
    isLiked: _safeBool(json, 'isLiked'),
    createdAt: json['createdAt'] != null 
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'author': author,
    'content': content,
    'postType': postType,
    'moodScore': moodScore,
    'isAnonymous': isAnonymous,
    'likesCount': likesCount,
    'commentsCount': commentsCount,
    'isLiked': isLiked,
    'createdAt': createdAt.toIso8601String(),
  };
}

// ─── CompletionTypeConfig ──────────────────────────────────────────────────
class CompletionTypeConfig {
  final String type;
  final Map<String, dynamic> config;

  CompletionTypeConfig({required this.type, required this.config});

  factory CompletionTypeConfig.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> safeConfig = {};
    final configValue = json['config'];
    if (configValue is Map) {
      safeConfig = Map<String, dynamic>.from(configValue);
    }
    
    return CompletionTypeConfig(
      type: _safeString(json, 'type', 'action'),
      config: safeConfig,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'config': config,
  };
}

// ─── Challenge (complet) ────────────────────────────────────────────────────
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
    final completionTypeData = json['completionType'] is Map
        ? Map<String, dynamic>.from(json['completionType'])
        : {'type': 'action', 'config': {}};
    
    return Challenge(
      id: _safeString(json, '_id', _safeString(json, 'id', '')),
      title: _safeString(json, 'title'),
      description: _safeString(json, 'description'),
      instructions: _safeStringList(json, 'instructions'),
      category: _safeString(json, 'category'),
      difficulty: _safeString(json, 'difficulty', 'easy'),
      durationMinutes: _safeInt(json, 'durationMinutes', 5),
      points: _safeInt(json, 'points', 10),
      icon: _safeString(json, 'icon', '⚡'),
      completionType: CompletionTypeConfig.fromJson(completionTypeData),
      targetMoods: _safeStringList(json, 'targetMoods'),
      requiredLevel: _safeString(json, 'requiredLevel', 'all'),
      isPremium: _safeBool(json, 'isPremium'),
      isActive: _safeBool(json, 'isActive', true),
      order: _safeInt(json, 'order'),
      isCompleted: _safeBool(json, 'isCompleted'),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'description': description,
    'instructions': instructions,
    'category': category,
    'difficulty': difficulty,
    'durationMinutes': durationMinutes,
    'points': points,
    'icon': icon,
    'completionType': completionType.toJson(),
    'targetMoods': targetMoods,
    'requiredLevel': requiredLevel,
    'isPremium': isPremium,
    'isActive': isActive,
    'order': order,
    'isCompleted': isCompleted,
  };
}