// lib/models/user.model.dart
class UserModel {
  final String id;
  final String name;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final int?    age;
  final String? city;
  final String? gender;
  final String? avatar;
  final String? anonymousAlias;
  final int     totalPoints;
  final String  level;
  final int     streakDays;
  final bool    isPremium;
  final UserPreferences preferences;
  final List<UserBadge> badges;

  const UserModel({
    required this.id,
    required this.name,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.age,
    this.city,
    this.gender,
    this.avatar,
    this.anonymousAlias,
    required this.totalPoints,
    required this.level,
    required this.streakDays,
    required this.isPremium,
    required this.preferences,
    this.badges = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:        json['id'] ?? json['_id'] ?? '',
    name:      json['name'] ?? '',
    firstName: json['firstName'],
    lastName:  json['lastName'],
    email:     json['email'],
    phone:     json['phone'],
    age:       json['age'],
    city:      json['city'],
    gender:    json['gender'],
    avatar:    json['avatar'],
    anonymousAlias: json['anonymousAlias'],
    totalPoints: json['totalPoints'] ?? 0,
    level:       json['level'] ?? 'bronze',
    streakDays:  json['streakDays'] ?? 0,
    isPremium:   json['isPremium'] ?? false,
    preferences: json['preferences'] != null
        ? UserPreferences.fromJson(json['preferences'])
        : const UserPreferences(),
    badges: (json['badges'] as List?)
        ?.map((b) => UserBadge.fromJson(b))
        .toList() ?? [],
  );

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
}

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
    notificationsEnabled: json['notificationsEnabled'] ?? true,
    reminderTime: json['reminderTime'] ?? '20:00',
    anonymousInCommunity: json['anonymousInCommunity'] ?? false,
    theme: json['theme'] ?? 'auto',
  );
}

class UserBadge {
  final String badgeId;
  final DateTime? earnedAt;

  const UserBadge({required this.badgeId, this.earnedAt});

  factory UserBadge.fromJson(Map<String, dynamic> json) => UserBadge(
    badgeId: json['badgeId'],
    earnedAt: json['earnedAt'] != null ? DateTime.parse(json['earnedAt']) : null,
  );
}

// ─── Mood Model ──────────────────────────────────────────────────────────────
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
    id: json['_id'],
    score: json['score'],
    label: json['label'],
    note: json['note'],
    factors: (json['factors'] as List?)?.map((f) => f.toString()).toList() ?? [],
    energyLevel: json['energyLevel'],
    date: json['date'],
    recordedAt: json['recordedAt'] != null ? DateTime.parse(json['recordedAt']) : null,
  );
}

// ─── Challenge Model ─────────────────────────────────────────────────────────
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
    id: json['_id'] ?? json['id'],
    title: json['title'],
    description: json['description'],
    instructions: (json['instructions'] as List?)?.map((i) => i.toString()).toList() ?? [],
    category: json['category'],
    difficulty: json['difficulty'] ?? 'easy',
    durationMinutes: json['durationMinutes'] ?? 5,
    points: json['points'] ?? 10,
    icon: json['icon'] ?? '⚡',
    targetMoods: (json['targetMoods'] as List?)?.map((m) => m.toString()).toList() ?? [],
    isPremium: json['isPremium'] ?? false,
    isCompleted: json['isCompleted'] ?? false,
    reason: json['reason'],
  );
}

// ─── Community Post Model ─────────────────────────────────────────────────────
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
    id: json['_id'] ?? json['id'],
    author: json['author'],
    content: json['content'],
    postType: json['postType'] ?? 'general',
    moodScore: json['moodScore'],
    isAnonymous: json['isAnonymous'] ?? false,
    likesCount: json['likesCount'] ?? 0,
    commentsCount: json['commentsCount'] ?? 0,
    isLiked: json['isLiked'] ?? false,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}