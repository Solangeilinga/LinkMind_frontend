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

  // ─── Rappel humeur quotidien ───────────────────────────────────────────────
  static Future<void> scheduleDailyMoodReminder(String time) async {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 20;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    await _plugin.cancel(1);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      1,
      'Comment tu te sens aujourd\'hui ? 😊',
      'Note ton humeur en 10 secondes et garde ton streak !',
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─── Alerte streak en danger ───────────────────────────────────────────────
  static Future<void> scheduleStreakWarning() async {
    final now = tz.TZDateTime.now(tz.local);
    final tonight = tz.TZDateTime(tz.local, now.year, now.month, now.day, 22, 0);
    if (tonight.isBefore(now)) return;

    await _plugin.zonedSchedule(
      2,
      '🔥 Ton streak est en danger !',
      'Tu n\'as pas encore noté ton humeur aujourd\'hui. Il reste ${tonight.difference(now).inHours}h.',
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Rappel défi non complété ──────────────────────────────────────────────
  static Future<void> scheduleChallengeReminder() async {
    final now = tz.TZDateTime.now(tz.local);
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
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

    final now = tz.TZDateTime.now(tz.local);
    var evening = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 30);
    if (evening.isBefore(now)) evening = evening.add(const Duration(days: 1));

    await _plugin.cancel(4);
    await _plugin.zonedSchedule(
      4,
      'LinkMind 💙',
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─── Configurer tous les rappels selon les préférences ────────────────────
  static Future<void> setupAllReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      final reminderTime = prefs.getString('reminder_time') ?? '20:00';

      if (!enabled) {
        await cancelAll();
        return;
      }

      await scheduleDailyMoodReminder(reminderTime).catchError((e) {
        _log.warning('Erreur scheduleDailyMoodReminder', e);
      });

      await scheduleEveningMessage().catchError((e) {
        _log.warning('Erreur scheduleEveningMessage', e);
      });
    } catch (e) {
      _log.warning('Erreur setupAllReminders', e);
    }
  }

  // ─── Afficher une notification immédiate (pour FCM foreground) ─────────────
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fcm_channel',
      'Notifications push',
      channelDescription: 'Notifications reçues depuis le serveur',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _plugin.show(id, title, body, details);
  }

  static Future<void> cancelAll() async => await _plugin.cancelAll();
  static Future<void> cancel(int id) async => await _plugin.cancel(id);

  // ─── Demander la permission (Android 13+) ─────────────────────────────────
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }
}