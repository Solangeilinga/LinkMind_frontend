import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../utils/theme.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/local_notification_service.dart';
import '../../services/api.service.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifEnabled = true;
  String _reminderTime = '20:00';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool('notifications_enabled') ?? true;
      _reminderTime = prefs.getString('reminder_time') ?? '20:00';
    });
  }

  Future<void> _saveNotifPref(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', val);
    setState(() => _notifEnabled = val);
    await LocalNotificationService.setupAllReminders();
  }

  Future<void> _saveReminderTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminder_time', time);
    setState(() => _reminderTime = time);
    await LocalNotificationService.scheduleDailyMoodReminder(time);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Paramètres', style: AppTextStyles.h3),
        elevation: 0,
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop()),
      ),
      body: ListView(children: [
        _SectionHeader('Apparence'),
        _SettingCard(children: [
          _SettingRow(
            icon: Icons.dark_mode_outlined,
            title: 'Thème',
            subtitle: _themeLabel(settings.themeMode),
            onTap: () => _showThemePicker(context, settings.themeMode, notifier),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.text_fields_outlined, size: 20, color: AppColors.onSurfaceMuted),
                const SizedBox(width: 12),
                Expanded(child: Text('Taille du texte', style: AppTextStyles.body)),
                Text('${(settings.textScale * 100).round()}%',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
              ]),
              Slider(
                value: settings.textScale,
                min: 0.85, max: 1.3, divisions: 9,
                activeColor: AppColors.primary,
                onChanged: (v) => notifier.setTextScale(v),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('A', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                Text('A', style: AppTextStyles.caption.copyWith(fontSize: 18)),
              ]),
            ])),
        ]),

        // Section Langue SUPPRIMÉE

        _SectionHeader('Notifications'),
        _SettingCard(children: [
          SwitchListTile(
            value: _notifEnabled,
            onChanged: _saveNotifPref,
            activeColor: AppColors.primary,
            title: Text('Notifications activées', style: AppTextStyles.body),
            subtitle: Text('Rappels humeur, streak, défis',
                style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
          ),
          if (_notifEnabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                const Icon(Icons.alarm_outlined, size: 20, color: AppColors.onSurfaceMuted),
                const SizedBox(width: 12),
                Expanded(child: Text('Rappel humeur quotidien', style: AppTextStyles.body)),
                DropdownButton<String>(
                  value: _reminderTime,
                  underline: const SizedBox(),
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w800),
                  items: List.generate(24, (i) =>
                    '${i.toString().padLeft(2, '0')}:00'
                  ).map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) { if (v != null) _saveReminderTime(v); },
                ),
              ])),
          ],
        ]),

        _SectionHeader('Compte'),
        _SettingCard(children: [
          _SettingRow(
            icon: Icons.download_outlined,
            title: 'Exporter mes données',
            subtitle: _exporting ? 'Export en cours...' : 'Télécharge toutes tes données (RGPD)',
            onTap: _exporting ? null : () => _exportData(context),
          ),
        ]),

        const SizedBox(height: 32),
        Center(child: Text('LinkMind v1.0.0',
            style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted))),
        const SizedBox(height: 24),
      ]),
    );
  }

  String _themeLabel(ThemeMode m) {
    if (m == ThemeMode.light) return 'Clair';
    if (m == ThemeMode.dark)  return 'Sombre';
    return 'Système';
  }

  void _showThemePicker(BuildContext context, ThemeMode current, AppSettingsNotifier notifier) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ...[
          (ThemeMode.system, '⚙️', 'Système (automatique)'),
          (ThemeMode.light,  '☀️', 'Clair'),
          (ThemeMode.dark,   '🌙', 'Sombre'),
        ].map((t) => ListTile(
          leading: Text(t.$2, style: const TextStyle(fontSize: 22)),
          title: Text(t.$3, style: AppTextStyles.body),
          trailing: current == t.$1
              ? const Icon(Icons.check, color: AppColors.primary) : null,
          onTap: () { notifier.setTheme(t.$1); Navigator.pop(context); },
        )),
        const SizedBox(height: 16),
      ]));
  }

  Future<void> _exportData(BuildContext context) async {
    setState(() => _exporting = true);
    try {
      final token = await ApiService().getAccessToken();
      final baseUrl = AppConstants.baseUrl;
      final dio = Dio();
      final dir = await getTemporaryDirectory();
      final date = DateTime.now().toIso8601String().split('T')[0];
      final path = '${dir.path}/linkmind-data-$date.json';

      await dio.download(
        '$baseUrl/users/me/export',
        path,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Fichier exporté invalide');
      }

      if (mounted) {
        setState(() => _exporting = false);
        _showExportSuccessDialog(path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : $e'), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  void _showExportSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.secondary, size: 28),
            SizedBox(width: 8),
            Text('Export terminé !'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vos données ont été exportées avec succès.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.data_usage, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path.split('/').last,
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await OpenFile.open(path);
              if (result.type != ResultType.done) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Impossible d\'ouvrir : ${result.message}')),
                );
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Ouvrir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Text(title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
            color: AppColors.onSurfaceMuted,
            fontWeight: FontWeight.w800, letterSpacing: .06)));
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.divider)),
    child: Column(children: children));
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? titleColor, iconColor;
  const _SettingRow({required this.icon, required this.title,
      this.subtitle, this.onTap, this.titleColor, this.iconColor});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 20,
        color: iconColor ?? AppColors.onSurfaceMuted),
    title: Text(title, style: AppTextStyles.body.copyWith(
        color: titleColor ?? AppColors.onSurface)),
    subtitle: subtitle != null
        ? Text(subtitle!, style: AppTextStyles.caption.copyWith(
            color: AppColors.onSurfaceMuted)) : null,
    trailing: onTap != null
        ? const Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceMuted) : null,
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  );
}