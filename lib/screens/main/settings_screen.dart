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
        title: const Text('Paramètres', style: AppTextStyles.h3),
        elevation: 0,
        backgroundColor: AppColors.surface,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(children: [
        const _SectionHeader('Apparence'),
        _SettingCard(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.text_fields_outlined,
                          size: 20, color: AppColors.onSurfaceMuted),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Text('Taille du texte',
                              style: AppTextStyles.body)),
                      Text('${(settings.textScale * 100).round()}%',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                    ]),
                    Slider(
                      value: settings.textScale,
                      min: 0.85,
                      max: 1.3,
                      divisions: 9,
                      activeColor: AppColors.primary,
                      onChanged: (v) => notifier.setTextScale(v),
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('A',
                              style:
                                  AppTextStyles.caption.copyWith(fontSize: 11)),
                          Text('A',
                              style:
                                  AppTextStyles.caption.copyWith(fontSize: 18)),
                        ]),
                  ])),
        ]),
        const _SectionHeader('Notifications'),
        _SettingCard(children: [
          SwitchListTile(
            value: _notifEnabled,
            onChanged: _saveNotifPref,
            activeThumbColor: AppColors.primary,
            title: const Text('Notifications activées', style: AppTextStyles.body),
            subtitle: Text('Rappels humeur, streak, défis',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.onSurfaceMuted)),
          ),
          if (_notifEnabled) ...[
            const Divider(height: 1),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(children: [
                  const Icon(Icons.alarm_outlined,
                      size: 20, color: AppColors.onSurfaceMuted),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('Rappel humeur quotidien',
                          style: AppTextStyles.body)),
                  DropdownButton<String>(
                    value: _reminderTime,
                    underline: const SizedBox(),
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w800),
                    items: List.generate(
                            24, (i) => '${i.toString().padLeft(2, '0')}:00')
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _saveReminderTime(v);
                    },
                  ),
                ])),
          ],
        ]),
        const SizedBox(height: 32),
        Center(
            child: Text('LinkMind v1.0.0',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.onSurfaceMuted))),
        const SizedBox(height: 24),
      ]),
    );
  }

  String _themeLabel(ThemeMode m) {
    return 'Clair';
  }

  Future<void> _exportData(BuildContext context) async {}
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
              fontWeight: FontWeight.w800,
              letterSpacing: .06)));
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
  final Color? titleColor;
  final Color? iconColor;

  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 20, color: iconColor ?? AppColors.onSurfaceMuted),
        title: Text(title,
            style: AppTextStyles.body
                .copyWith(color: titleColor ?? AppColors.onSurface)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.onSurfaceMuted))
            : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right,
                size: 18, color: AppColors.onSurfaceMuted)
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );
}