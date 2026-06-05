import 'package:flutter/material.dart';

/// Central icon mapping: Replaces emojis with Material Design icons for a professional look
class IconMapper {
  static const double _defaultSize = 24;

  /// Get a Material Design icon widget for common use cases
  /// Returns Icon widget or fallback emoji if no mapping exists
  static Widget getIcon(
    String emoji, {
    double size = _defaultSize,
    Color? color,
    bool useFallback = false,
  }) {
    final icon = _emojiToIconData(emoji);

    if (icon == null) {
      // Fallback to emoji if no mapping exists
      if (useFallback) {
        return Text(
          emoji,
          style: TextStyle(fontSize: size),
        );
      }
      // Default to a generic icon
      return Icon(Icons.circle_outlined, size: size, color: color);
    }

    return Icon(icon, size: size, color: color);
  }

  /// Map emoji to MaterialIcons IconData
  static IconData? _emojiToIconData(String emoji) {
    final map = {
      // Starters & Moods
      '🌟': Icons.star_rate,
      '💪': Icons.fitness_center,
      '🧘': Icons.self_improvement,
      '📚': Icons.library_books,
      '💚': Icons.favorite,
      '🎯': Icons.radio_button_checked,
      '😴': Icons.bedtime,
      '🤝': Icons.handshake,

      // Moods
      '😄': Icons.sentiment_very_satisfied,
      '🙂': Icons.sentiment_satisfied,
      '😐': Icons.sentiment_neutral,
      '😔': Icons.sentiment_dissatisfied,
      '😰': Icons.sentiment_very_dissatisfied,
      '😟': Icons.sentiment_dissatisfied,
      '😢': Icons.sentiment_very_dissatisfied,
      '😌': Icons.self_improvement,

      // Common
      '🔒': Icons.lock,
      '👑': Icons.workspace_premium,
      '💛': Icons.favorite,
      '🏥': Icons.local_hospital,
      '🏫': Icons.school,
      '📞': Icons.phone,
      '💳': Icons.credit_card,
      '📱': Icons.smartphone,
      '📅': Icons.calendar_today,
      '📊': Icons.bar_chart,
      '🎁': Icons.card_giftcard,
      '🔥': Icons.local_fire_department,
      '⚡': Icons.flash_on,
      '💬': Icons.chat,
      '💡': Icons.lightbulb,
      '🏆': Icons.emoji_events,
      '🏅': Icons.military_tech,
      '🌍': Icons.public,
      '🎭': Icons.theater_comedy,
      '👥': Icons.group,
      '🌱': Icons.eco,
      '🔍': Icons.search,
      '📋': Icons.assignment,
      '🌐': Icons.language,
      '👤': Icons.person,
      '🎉': Icons.celebration,
      '🚔': Icons.local_police,
      '🚒': Icons.fire_truck,
      '🌿': Icons.nature,
      '📧': Icons.mail,
      '❤️': Icons.favorite,
      '🛡️': Icons.security,
      '⏱️': Icons.timer,
      '💭': Icons.comment,
      '💰': Icons.attach_money,
      '🩺': Icons.medical_information,
      '🚨': Icons.warning,
      '👍': Icons.thumb_up,
    };

    return map[emoji];
  }

  /// For Dart/Flutter backend integration: Get emoji string for a given key
  /// Used when you need to know what emoji corresponds to an action
  static String getEmojiForKey(String key) {
    final map = {
      'star': '🌟',
      'strength': '💪',
      'meditation': '🧘',
      'study': '📚',
      'heart': '💚',
      'target': '🎯',
      'sleep': '😴',
      'community': '🤝',
      'lock': '🔒',
      'premium': '👑',
      'hospital': '🏥',
      'school': '🏫',
      'phone': '📞',
      'card': '💳',
      'phone_device': '📱',
      'calendar': '📅',
      'chart': '📊',
      'gift': '🎁',
      'fire': '🔥',
      'lightning': '⚡',
      'chat': '💬',
      'idea': '💡',
      'trophy': '🏆',
      'badge': '🏅',
      'world': '🌍',
      'theater': '🎭',
      'group': '👥',
      'plant': '🌱',
      'search': '🔍',
      'clipboard': '📋',
      'globe': '🌐',
      'user': '👤',
      'celebration': '🎉',
      'police': '🚔',
      'fire_truck': '🚒',
      'leaf': '🌿',
      'email': '📧',
      'heart_red': '❤️',
      'shield': '🛡️',
      'timer': '⏱️',
      'comment': '💭',
      'money': '💰',
      'medical': '🩺',
      'alert': '🚨',
      'thumbs_up': '👍',
    };
    return map[key] ?? '⭕';
  }

  /// Get display name for a mood emoji
  static String getMoodLabel(String emoji) {
    final map = {
      '😄': 'Super bien',
      '🙂': 'Bien',
      '😐': 'Neutre',
      '😔': 'Fatigué(e)',
      '😰': 'Stressé(e)',
      '😟': 'Anxieux(se)',
      '😢': 'Triste',
      '😌': 'Calme',
    };
    return map[emoji] ?? 'Inconnu';
  }

  /// Create a professional icon row (used in lists/grids)
  static Widget buildIconRow(
    List<(String emoji, String label)> items, {
    double iconSize = 24,
    Color? iconColor,
  }) {
    return Row(
      children: items
          .asMap()
          .entries
          .expand((e) sync* {
            yield Tooltip(
              message: e.value.$2,
              child: getIcon(
                e.value.$1,
                size: iconSize,
                color: iconColor,
              ),
            );
            if (e.key < items.length - 1) yield const SizedBox(width: 8);
          })
          .toList(),
    );
  }
}
