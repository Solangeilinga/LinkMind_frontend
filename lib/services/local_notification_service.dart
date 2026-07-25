import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:logging/logging.dart';

final _log = Logger('LocalNotificationService');

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  // ─── Rappel humeur — texte contextuel selon dernière humeur ───────────────
  static Future<void> scheduleDailyMoodReminder(
    String time, {
    String? lastMoodLabel,
    int? streakDays,
    int? badgesNeeded,  // combien de jours manquent pour le prochain badge
  }) async {
    final parts = time.split(':');
    final hour   = int.tryParse(parts[0]) ?? 20;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    await _plugin.cancel(1);

    // Titre et corps contextuels
    String title;
    String body;

    if (streakDays != null && streakDays >= 3) {
      title = '🔥 $streakDays jours de suite !';
      body  = 'Note ton humeur pour garder ton streak et ne pas tout perdre.';
    } else if (lastMoodLabel == 'sad' || lastMoodLabel == 'anxious' || lastMoodLabel == 'stressed') {
      title = 'Comment tu vas aujourd\'hui ? 💙';
      body  = 'Hier tu traversais une période difficile. On est là si tu veux en parler.';
    } else if (lastMoodLabel == 'happy' || lastMoodLabel == 'excited') {
      title = 'Tu étais de bonne humeur hier 😊';
      body  = 'Note ton humeur d\'aujourd\'hui et suis ton évolution !';
    } else if (badgesNeeded != null && badgesNeeded <= 3) {
      title = 'Plus que $badgesNeeded jour${badgesNeeded > 1 ? 's' : ''} pour ton badge 🏅';
      body  = 'Note ton humeur maintenant et débloque ta prochaine récompense.';
    } else {
      title = 'Comment tu te sens aujourd\'hui ? 😊';
      body  = 'Note ton humeur en 10 secondes et garde ton streak !';
    }

    final now       = tz.TZDateTime.now(tz.local);
    var scheduled   = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      1,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mood_reminder', 'Rappel humeur',
          channelDescription: 'Rappel quotidien pour noter ton humeur',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─── Alerte streak en danger ───────────────────────────────────────────────
  static Future<void> scheduleStreakWarning({int streakDays = 0}) async {
    final now     = tz.TZDateTime.now(tz.local);
    final tonight = tz.TZDateTime(tz.local, now.year, now.month, now.day, 22, 0);
    if (tonight.isBefore(now)) return;

    final title = streakDays >= 7
        ? '🔥 $streakDays jours — ne laisse pas tomber !'
        : '🔥 Ton streak est en danger !';
    final body = streakDays >= 7
        ? 'Tu as construit quelque chose d\'impressionnant. Note ton humeur avant minuit.'
        : 'Tu n\'as pas encore noté ton humeur aujourd\'hui. Il te reste encore du temps !';

    await _plugin.zonedSchedule(
      2,
      title,
      body,
      tonight,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_warning', 'Alerte streak',
          channelDescription: 'Alerte si le streak est en danger',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Rappel défi non complété ──────────────────────────────────────────────
  static Future<void> scheduleChallengeReminder() async {
    final now      = tz.TZDateTime.now(tz.local);
    final reminder = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 0);
    if (reminder.isBefore(now)) return;

    await _plugin.zonedSchedule(
      3,
      'Ton défi t\'attend ⚡',
      'Tu as un défi bien-être à compléter aujourd\'hui. Ça prend moins de 5 minutes !',
      reminder,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'challenge_reminder', 'Rappel défi',
          channelDescription: 'Rappel pour compléter le défi du jour',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Notification retour J+3 ──────────────────────────────────────────────
  // Planifiée une seule fois après inscription, à J+3 à 19h.
  static Future<void> scheduleJ3ReturnNotif({
    required int currentStreak,
    required int badgeThreshold, // ex: 7 pour le premier badge streak
  }) async {
    final prefs       = await SharedPreferences.getInstance();
    final alreadySent = prefs.getBool('j3_notif_sent') ?? false;
    if (alreadySent) return;

    final now  = tz.TZDateTime.now(tz.local);
    final j3   = tz.TZDateTime(tz.local, now.year, now.month, now.day + 3, 19, 0);

    final remaining = badgeThreshold - currentStreak;
    final body = remaining > 0
        ? 'Tu as $currentStreak entrée${currentStreak > 1 ? 's' : ''}. '
          'Encore $remaining jour${remaining > 1 ? 's' : ''} pour ton badge Streak !'
        : 'Tu progresses bien ! Ouvre BASYAM pour voir ton évolution.';

    await _plugin.zonedSchedule(
      5,
      '🌱 Tu construis quelque chose',
      body,
      j3,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'engagement', 'Engagement',
          channelDescription: 'Notifications d\'engagement et de progression',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    await prefs.setBool('j3_notif_sent', true);
  }

  // ─── Message bienveillant du soir ─────────────────────────────────────────
  static Future<void> scheduleEveningMessage() async {
    final messages = [
      'Tu as passé une belle journée 🌙 Prends soin de toi ce soir.',
      'Rappelle-toi : prendre soin de soi n\'est pas un luxe. Bonne nuit 💙',
      'Chaque jour est une nouvelle chance. Tu t\'en sors très bien 🌱',
      'Repose-toi bien. Demain est un nouveau jour 😊',
    ];
    final msg = messages[DateTime.now().weekday % messages.length];

    final now     = tz.TZDateTime.now(tz.local);
    var evening   = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 30);
    if (evening.isBefore(now)) evening = evening.add(const Duration(days: 1));

    await _plugin.cancel(4);
    await _plugin.zonedSchedule(
      4,
      'BASYAM 💙',
      msg,
      evening,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_message', 'Message du soir',
          channelDescription: 'Message bienveillant chaque soir',
          importance: Importance.low,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─── Configurer tous les rappels selon les préférences ───────────────────
  static Future<void> setupAllReminders({
    String? lastMoodLabel,
    int? streakDays,
    int? badgesNeeded,
  }) async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final enabled     = prefs.getBool('notifications_enabled') ?? true;
      final reminderTime = prefs.getString('reminder_time') ?? '20:00';

      if (!enabled) {
        await cancelAll();
        return;
      }

      await scheduleDailyMoodReminder(
        reminderTime,
        lastMoodLabel: lastMoodLabel,
        streakDays: streakDays,
        badgesNeeded: badgesNeeded,
      ).catchError((e) => _log.warning('scheduleDailyMoodReminder error', e));

      await scheduleEveningMessage()
          .catchError((e) => _log.warning('scheduleEveningMessage error', e));

      if (streakDays != null) {
        await scheduleStreakWarning(streakDays: streakDays)
            .catchError((e) => _log.warning('scheduleStreakWarning error', e));
      }
    } catch (e) {
      _log.warning('setupAllReminders error', e);
    }
  }

  // ─── Afficher une notification immédiate (FCM foreground) ─────────────────
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'fcm_channel', 'Notifications push',
        channelDescription: 'Notifications reçues depuis le serveur',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();
  static Future<void> cancel(int id) async => _plugin.cancel(id);

  static Future<bool> requestPermission() async {
    bool granted = false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = (await android.requestNotificationsPermission()) ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted = (await ios.requestPermissions(
            alert: true, badge: true, sound: true)) ??
          false;
    }
    return granted;
  }
}