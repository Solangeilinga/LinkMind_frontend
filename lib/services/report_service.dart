import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_save_directory/file_save_directory.dart';
import '../models/models.dart';

class ReportService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF77021D);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFFF5B731);
  static const PdfColor darkColor = PdfColor.fromInt(0xFF1A0A0D);
  static const PdfColor mutedColor = PdfColor.fromInt(0xFF8A7070);
  static const PdfColor bgColor = PdfColor.fromInt(0xFFFAF7F5);
  static const double defaultMargin = 35.0;
  static const double spacing = 20.0;

  static Future<void> generateAndShowReport({
    required UserModel user,
    required List<Map<String, dynamic>> moodHistory,
    required List<Map<String, dynamic>> challenges,
    required List<UserBadge> badges,
    String? personalizedMessage,
  }) async {
    try {
      final pdf = pw.Document();

      final avgScore = _calculateAverageScore(moodHistory);
      final wellnessScore = _calculateWellnessScore(avgScore, challenges, badges);
      final trends = _analyzeTrends(moodHistory);
      final topHours = _analyzeMoodByHour(moodHistory);
      final challengeStats = _analyzeChallengesByCategory(challenges);
      final earnedBadges = badges.where((b) => b.earnedAt != null).toList();

      // Page 1
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(defaultMargin),
          build: (context) => _buildPage1(
            user,
            moodHistory,
            avgScore,
            wellnessScore,
            trends,
            topHours,
            challengeStats,
            earnedBadges,
            challenges,
          ),
        ),
      );

      // Page 2 (seulement si elle a du contenu utile)
      final hasRecos = _hasRecommendations(avgScore, challenges, earnedBadges);
      if (hasRecos || (personalizedMessage != null && personalizedMessage.isNotEmpty)) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(defaultMargin),
            build: (context) => _buildPage2(
              avgScore,
              trends,
              challenges,
              earnedBadges,
              personalizedMessage,
            ),
          ),
        );
      }

      final pdfBytes = await pdf.save();

      // Sauvegarde ou partage selon la plateforme
      if (Platform.isAndroid) {
        // Sauvegarder dans Téléchargements
        final fileName = 'LinkMind_Report_${DateTime.now().toIso8601String()}.pdf';
        final result = await FileSaveDirectory.instance.saveFile(
          fileName: fileName,
          fileBytes: pdfBytes,
          location: SaveLocation.downloads,
          openAfterSave: false,
        );
        if (result == true) {
          debugPrint('✅ PDF sauvegardé dans Téléchargements');
          await _openDownloadFolder();
        } else {
          debugPrint('❌ Échec de la sauvegarde');
          // Fallback : proposer le partage
          await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
        }
      } else {
        // iOS / autres : partage natif
        await Printing.layoutPdf(
          name: 'LinkMind_Report_${DateTime.now().toIso8601String()}.pdf',
          format: PdfPageFormat.a4,
          onLayout: (format) async => pdfBytes,
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Erreur génération rapport: $e');
      debugPrint(stack.toString());
      // En cas d'erreur, essayer au moins de partager le PDF s'il existe
      // (l'utilisateur verra un message d'erreur mais pourra partager)
    }
  }

  static Future<void> _openDownloadFolder() async {
    if (Platform.isAndroid) {
      const downloadUri = 'content://com.android.externalstorage.documents/document/primary%3ADownload';
      try {
        await launchUrl(Uri.parse(downloadUri));
      } catch (e) {
        debugPrint('Impossible d\'ouvrir le dossier Téléchargements: $e');
      }
    }
  }

  static bool _hasRecommendations(double avgScore, List<Map<String, dynamic>> challenges, List<UserBadge> badges) {
    final recs = _buildRecommendationsList(avgScore, challenges, badges);
    return recs.isNotEmpty;
  }

  // ==================== PAGE 1 ====================

  static List<pw.Widget> _buildPage1(
    UserModel user,
    List<Map<String, dynamic>> moodHistory,
    double avgScore,
    int wellnessScore,
    Map<String, dynamic> trends,
    List<Map<String, dynamic>> topHours,
    List<Map<String, dynamic>> challengeStats,
    List<UserBadge> earnedBadges,
    List<Map<String, dynamic>> challenges,
  ) {
    final widgets = <pw.Widget>[];

    // HEADER
    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: spacing),
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: primaryColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('LinkMind',
                style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.SizedBox(height: 8),
            pw.Text('Rapport de bien-être personnalisé',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
            pw.SizedBox(height: 6),
            pw.Text(
                'Généré le ${DateFormat('d MMMM yyyy', 'fr_FR').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
          ],
        ),
      ),
    );

    // SALUTATION
    final firstName = _safeString(user.firstName);
    final name = _safeString(user.name);
    final userName = firstName.isNotEmpty ? firstName : (name.isNotEmpty ? name : 'utilisateur');
    widgets.add(pw.Text('Bonjour $userName 👋',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
    widgets.add(pw.SizedBox(height: 12));

    // STATS RAPIDES
    widgets.add(
      pw.Row(
        children: [
          _buildStatCard('Score', '$wellnessScore%', '⭐'),
          pw.SizedBox(width: 8),
          _buildStatCard('Niveau', _capitalizeFirst(_safeString(user.level), defaultText: 'Débutant'), '🏆'),
          pw.SizedBox(width: 8),
          _buildStatCard('Humeur moy.', '${avgScore.toStringAsFixed(1)}/5', '😊'),
          pw.SizedBox(width: 8),
          _buildStatCard('Défis', '${challenges.length}', '🎯'),
        ],
      ),
    );
    widgets.add(pw.SizedBox(height: spacing));

    // BIEN-ÊTRE
    widgets.add(_buildSectionTitle('Votre bien-être émotionnel'));
    if (moodHistory.isEmpty) {
      widgets.add(_buildEmptyMessage('Aucune donnée d\'humeur enregistrée. Commencez à suivre votre humeur pour des analyses personnalisées.'));
    } else {
      widgets.add(_buildWellbeingAnalysis(moodHistory, avgScore, trends));
    }
    widgets.add(pw.SizedBox(height: 16));

    // MEILLEURS MOMENTS
    if (topHours.isNotEmpty && moodHistory.isNotEmpty) {
      widgets.add(_buildSectionTitle('Vos meilleurs moments'));
      widgets.add(_buildBestHoursAnalysis(topHours));
      widgets.add(pw.SizedBox(height: 16));
    }

    // DÉFIS
    if (challenges.isNotEmpty && challengeStats.isNotEmpty) {
      widgets.add(_buildSectionTitle('Vos défis et progression'));
      widgets.add(_buildChallengesAnalysis(challenges, challengeStats));
      widgets.add(pw.SizedBox(height: 16));
    } else if (challenges.isEmpty) {
      widgets.add(_buildSectionTitle('Vos défis'));
      widgets.add(_buildEmptyMessage('Aucun défi complété pour le moment. Relevez des défis pour progresser !'));
      widgets.add(pw.SizedBox(height: 16));
    }

    // BADGES
    widgets.add(_buildSectionTitle('Vos badges'));
    if (earnedBadges.isEmpty) {
      widgets.add(_buildEmptyMessage('Aucun badge débloqué. Continuez vos actions pour gagner des récompenses.'));
    } else {
      widgets.add(_buildBadgesAnalysis(earnedBadges));
    }

    return widgets;
  }

  // ==================== PAGE 2 ====================

  static List<pw.Widget> _buildPage2(
    double avgScore,
    Map<String, dynamic> trends,
    List<Map<String, dynamic>> challenges,
    List<UserBadge> earnedBadges,
    String? personalizedMessage,
  ) {
    final widgets = <pw.Widget>[];

    // RECOMMANDATIONS
    widgets.add(_buildSectionTitle('Vos recommandations'));
    final recs = _buildRecommendationsList(avgScore, challenges, earnedBadges);
    if (recs.isEmpty) {
      widgets.add(_buildEmptyMessage('Aucune recommandation spécifique pour le moment. Continuez vos efforts !'));
    } else {
      widgets.add(_buildRecommendationsWidget(recs));
    }
    widgets.add(pw.SizedBox(height: spacing));

    // MESSAGE PERSONNALISÉ
    widgets.add(_buildSectionTitle('Message personnalisé de Mindo'));
    widgets.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: primaryColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          personalizedMessage ?? 'Prends soin de toi au quotidien. Mindo est là pour toi.',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.white, height: 1.6),
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 30));

    // FOOTER
    widgets.add(pw.Divider(color: mutedColor));
    widgets.add(pw.Text(
      'LinkMind — Ton espace confidentiel de bien-être',
      textAlign: pw.TextAlign.center,
      style: const pw.TextStyle(fontSize: 8, color: mutedColor),
    ));

    return widgets;
  }

  // ==================== COMPOSANTS RÉUTILISABLES ====================

  static pw.Widget _buildStatCard(String label, String value, String icon) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border.all(color: secondaryColor, width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(icon, style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 6),
            pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor)),
            pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: mutedColor)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor)),
        pw.SizedBox(height: 6),
        pw.Container(height: 2, color: secondaryColor),
        pw.SizedBox(height: 8),
      ],
    );
  }

static pw.Widget _buildEmptyMessage(String message) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: bgColor,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: mutedColor.withAlpha(0.4), width: 0.5),
    ),
    child: pw.Text(
      message,
      style: pw.TextStyle(fontSize: 9, color: mutedColor, fontStyle: pw.FontStyle.italic),
      textAlign: pw.TextAlign.center,
    ),
  );
}

  static pw.Widget _buildWellbeingAnalysis(
    List<Map<String, dynamic>> moodHistory,
    double avgScore,
    Map<String, dynamic> trends,
  ) {
    final recent = moodHistory.length > 14 ? moodHistory.sublist(moodHistory.length - 14) : moodHistory;
    final scores = recent.map((m) => _toInt(m['score'], defaultValue: 3)).toList();
    final min = scores.reduce((a, b) => a < b ? a : b);
    final max = scores.reduce((a, b) => a > b ? a : b);

    String analysis = 'Humeur moyenne: ${avgScore.toStringAsFixed(1)}/5. ';

    if (scores.every((s) => s >= 4)) {
      analysis += 'Excellent! Vous êtes en très bonne forme mentale. Continuez!';
    } else if (scores.every((s) => s <= 2)) {
      analysis += 'Vous traversez une période difficile. Pensez à prendre soin de vous.';
    } else if (max - min >= 3) {
      analysis += 'Vos émotions fluctuent. C\'est normal! Essayez d\'identifier ce qui améliore votre humeur.';
    } else {
      analysis += 'Votre humeur est stable. C\'est une bonne base pour progresser.';
    }

    analysis += ' ${_safeString(trends['interpretation'])}';

    return pw.Text(
      analysis,
      style: const pw.TextStyle(fontSize: 9, color: darkColor, height: 1.6),
    );
  }

  static pw.Widget _buildBestHoursAnalysis(List<Map<String, dynamic>> topHours) {
    final hoursText = topHours.map((h) {
      final hour = _toInt(h['hour'], defaultValue: 0);
      final avg = _toDouble(h['avg'], defaultValue: 0.0);
      final label = hour == 0 ? 'Minuit'
          : hour < 12 ? '${hour}h du matin'
          : hour == 12 ? 'Midi'
          : '${hour}h du soir';
      return '$label (${avg.toStringAsFixed(1)}/5)';
    }).join(' - ');

    return pw.Text(
      'Vous êtes généralement de meilleure humeur: $hoursText',
      style: const pw.TextStyle(fontSize: 9, color: darkColor, height: 1.6),
    );
  }

  static pw.Widget _buildChallengesAnalysis(
    List<Map<String, dynamic>> challenges,
    List<Map<String, dynamic>> stats,
  ) {
    final catText = stats.map((c) => '${_safeString(c['category'])} (${c['count'] ?? 0})').join(', ');
    return pw.Text(
      'Vous avez relevé ${challenges.length} défis: $catText',
      style: const pw.TextStyle(fontSize: 9, color: darkColor, height: 1.6),
    );
  }

  static pw.Widget _buildBadgesAnalysis(List<UserBadge> badges) {
    final badgeText = badges.take(8).map((b) => '🏅 ${_safeString(b.badgeId)}').join(' - ');
    final extra = badges.length > 8 ? ' ... et ${badges.length - 8} autres' : '';
    return pw.Text(
      '$badgeText$extra',
      style: const pw.TextStyle(fontSize: 9, color: darkColor, height: 1.6),
    );
  }

  static List<String> _buildRecommendationsList(double avgScore, List<Map<String, dynamic>> challenges, List<UserBadge> badges) {
    final recs = <String>[];
    if (avgScore < 3) recs.add('Essayez les exercices de relaxation pour améliorer votre bien-être');
    if (challenges.length < 5) {
      recs.add('Complétez plus de défis pour renforcer votre confiance');
    } else {
      recs.add('Excellent engagement! Continuez à relever des défis régulièrement');
    }
    if (badges.isNotEmpty && badges.length > 5) recs.add('Superbe progression! Vous avez ${badges.length} badges');
    return recs;
  }

  static pw.Widget _buildRecommendationsWidget(List<String> recommendations) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: recommendations.map((rec) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(color: bgColor, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text(rec, style: const pw.TextStyle(fontSize: 8, color: darkColor)),
        ),
      )).toList(),
    );
  }

  // ==================== CALCULS SÉCURISÉS ====================

  static double _calculateAverageScore(List<Map<String, dynamic>> moodHistory) {
    if (moodHistory.isEmpty) return 3.0;
    double sum = 0;
    for (final m in moodHistory) {
      sum += _toDouble(m['score'], defaultValue: 3.0);
    }
    return sum / moodHistory.length;
  }

  static int _calculateWellnessScore(double avgScore, List<Map<String, dynamic>> challenges, List<UserBadge> badges) {
    final moodComponent = (avgScore / 5) * 40;
    final challengeComponent = (challenges.length * 5).clamp(0, 30).toDouble();
    final earnedCount = badges.where((b) => b.earnedAt != null).length;
    final badgeComponent = (earnedCount * 10).clamp(0, 30).toDouble();
    return (moodComponent + challengeComponent + badgeComponent).round();
  }

  static Map<String, dynamic> _analyzeTrends(List<Map<String, dynamic>> moodHistory) {
    if (moodHistory.length < 2) {
      return {'trend': 'stable', 'percentage': 0, 'interpretation': 'Données insuffisantes pour analyser la tendance.'};
    }
    final mid = (moodHistory.length / 2).floor();
    final firstHalf = moodHistory.sublist(0, mid);
    final secondHalf = moodHistory.sublist(mid);

    double avgFirst = 0;
    for (final e in firstHalf) {
      avgFirst += _toDouble(e['score'], defaultValue: 3.0);
    }
    avgFirst /= firstHalf.length;

    double avgSecond = 0;
    for (final e in secondHalf) {
      avgSecond += _toDouble(e['score'], defaultValue: 3.0);
    }
    avgSecond /= secondHalf.length;

    final diff = avgSecond - avgFirst;
    final percentage = avgFirst > 0 ? ((diff.abs() * 100) / avgFirst).round() : 0;

    if (diff > 0.2) {
      return {'trend': 'amélioration', 'percentage': percentage, 'interpretation': 'Votre bien-être s\'améliore! Continuez ainsi.'};
    } else if (diff < -0.2) {
      return {'trend': 'baisse', 'percentage': percentage, 'interpretation': 'Votre humeur baisse. Prenez du temps pour vous.'};
    }
    return {'trend': 'stable', 'percentage': 0, 'interpretation': 'Votre humeur reste stable. Bonne base pour progresser.'};
  }

  static List<Map<String, dynamic>> _analyzeMoodByHour(List<Map<String, dynamic>> moodHistory) {
    final hourMap = <int, List<int>>{};
    for (final m in moodHistory) {
      final dateValue = m['date'];
      if (dateValue != null) {
        DateTime? dateTime;
        if (dateValue is DateTime) {
          dateTime = dateValue;
        } else if (dateValue is String) dateTime = DateTime.tryParse(dateValue);
        if (dateTime != null) {
          final hour = dateTime.hour;
          hourMap.putIfAbsent(hour, () => []);
          hourMap[hour]!.add(_toInt(m['score'], defaultValue: 3));
        }
      }
    }
    final result = hourMap.entries.map((e) {
      final scores = e.value;
      final avg = scores.isEmpty ? 0.0 : scores.fold<int>(0, (a, b) => a + b) / scores.length;
      return {'hour': e.key, 'avg': avg};
    }).toList();
    result.sort((a, b) => (b['avg'] as num).compareTo(a['avg'] as num));
    return result.take(3).toList();
  }

  static List<Map<String, dynamic>> _analyzeChallengesByCategory(List<Map<String, dynamic>> challenges) {
    final catMap = <String, int>{};
    for (final ch in challenges) {
      final challengeMap = ch['challenge'] as Map<String, dynamic>?;
      final cat = _safeString(challengeMap?['category']);
      final category = cat.isEmpty ? 'Général' : cat;
      catMap[category] = (catMap[category] ?? 0) + 1;
    }
    final result = catMap.entries.map((e) => {'category': e.key, 'count': e.value}).toList();
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  static String _capitalizeFirst(String text, {String defaultText = ''}) {
    if (text.isEmpty) return defaultText;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static int _toInt(dynamic value, {int defaultValue = 3}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double _toDouble(dynamic value, {double defaultValue = 3.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}