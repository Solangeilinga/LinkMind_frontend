import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool   _notifEnabled  = true;
  String _reminderTime  = '20:00';
  bool   _isExporting   = false;
  bool   _isDeletingAccount = false;

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
    final user  = ref.read(authProvider).user;
    final moodState = ref.read(moodProvider);
    final lastMood  = moodState.todayMood?['label'] as String?;
    await LocalNotificationService.setupAllReminders(
      lastMoodLabel: lastMood,
      streakDays:    user?.streakDays,
    );
  }

  Future<void> _saveReminderTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminder_time', time);
    setState(() => _reminderTime = time);
    final user     = ref.read(authProvider).user;
    final moodState = ref.read(moodProvider);
    final lastMood  = moodState.todayMood?['label'] as String?;
    await LocalNotificationService.scheduleDailyMoodReminder(
      time,
      lastMoodLabel: lastMood,
      streakDays:    user?.streakDays,
    );
  }

  // ── Export données ─────────────────────────────────────────────────────────
  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      await ApiService().get('/users/me/export');
      if (mounted) {
        _showSnack(
          '📦 Tes données ont été envoyées à ton adresse email.',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur lors de l\'export. Réessaie.', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Suppression compte ─────────────────────────────────────────────────────
  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Row(children: [
          Text('🗑️', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Text('Supprimer le compte'),
        ]),
        content: const Text(
          'Cette action est irréversible.\n\n'
          'Toutes tes données (humeurs, défis, posts) seront supprimées définitivement dans les 30 jours, '
          'conformément à notre politique de confidentialité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Supprimer mon compte'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Double confirmation avec saisie
    final reconfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
          title: const Text('Confirme la suppression'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Tape "SUPPRIMER" pour confirmer :'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'SUPPRIMER',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ValueListenableBuilder(
              valueListenable: ctrl,
              builder: (_, val, __) => ElevatedButton(
                onPressed: val.text.trim() == 'SUPPRIMER'
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent),
                child: const Text('Confirmer'),
              ),
            ),
          ],
        );
      },
    );

    if (reconfirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ApiService().delete('/users/me');
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/auth/login');
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        _showSnack('Erreur. Contacte le support si le problème persiste.', isSuccess: false);
      }
    }
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppColors.secondary : AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final user     = ref.watch(authProvider).user;
    final isDark   = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres', style: AppTextStyles.h3),
        elevation: 0,
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isDeletingAccount
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Suppression en cours...', style: AppTextStyles.body),
                ],
              ),
            )
          : ListView(children: [

              // ── Apparence ────────────────────────────────────────────────
              const _SectionHeader('Apparence'),
              _SettingCard(children: [
                // Dark mode toggle
                SwitchListTile(
                  value: isDark,
                  onChanged: (_) => notifier.toggleDarkMode(),
                  activeThumbColor: AppColors.primary,
                  secondary: Icon(
                    isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    size: 20,
                    color: AppColors.onSurfaceMuted,
                  ),
                  title: Text(
                    isDark ? 'Mode sombre' : 'Mode clair',
                    style: AppTextStyles.body,
                  ),
                  subtitle: Text(
                    'Adapte l\'interface à la luminosité',
                    style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                  ),
                ),
                const Divider(height: 1),
                // Taille du texte
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.text_fields_outlined,
                            size: 20, color: AppColors.onSurfaceMuted),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Taille du texte', style: AppTextStyles.body)),
                        Text(
                          '${(settings.textScale * 100).round()}%',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w800),
                        ),
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
                    ],
                  ),
                ),
              ]),

              // ── Sons ─────────────────────────────────────────────────────
              const _SectionHeader('Sons'),
              _SettingCard(children: [
                SwitchListTile(
                  value: settings.soundsEnabled,
                  onChanged: (v) => notifier.setSoundsEnabled(v),
                  activeThumbColor: AppColors.primary,
                  secondary: Icon(
                    settings.soundsEnabled
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                    size: 20,
                    color: AppColors.onSurfaceMuted,
                  ),
                  title: const Text('Sons de l\'application', style: AppTextStyles.body),
                  subtitle: Text(
                    'Sons doux pour les exercices de respiration et confirmations',
                    style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                  ),
                ),
              ]),

              // ── Notifications ─────────────────────────────────────────────
              const _SectionHeader('Notifications'),
              _SettingCard(children: [
                SwitchListTile(
                  value: _notifEnabled,
                  onChanged: _saveNotifPref,
                  activeThumbColor: AppColors.primary,
                  title: const Text('Notifications activées', style: AppTextStyles.body),
                  subtitle: Text(
                    'Rappels humeur, streak, défis',
                    style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                  ),
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
                        child: Text('Rappel humeur quotidien', style: AppTextStyles.body),
                      ),
                      DropdownButton<String>(
                        value: _reminderTime,
                        underline: const SizedBox(),
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w800),
                        items: List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00')
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) { if (v != null) _saveReminderTime(v); },
                      ),
                    ]),
                  ),
                ],
              ]),

              // ── Mon compte ────────────────────────────────────────────────
              const _SectionHeader('Mon compte'),
              _SettingCard(children: [
                if (user?.email != null)
                  _SettingRow(
                    icon: Icons.email_outlined,
                    title: user!.email!,
                    subtitle: 'Adresse email',
                  ),
                if (user?.email != null) const Divider(height: 1),
                _SettingRow(
                  icon: Icons.lock_outline,
                  title: 'Changer le mot de passe',
                  onTap: () => context.push('/settings/change-password'),
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.logout,
                  title: 'Se déconnecter',
                  onTap: () => _showLogoutDialog(),
                ),
              ]),

              // ── Mes données ───────────────────────────────────────────────
              const _SectionHeader('Mes données'),
              _SettingCard(children: [
                _SettingRow(
                  icon: Icons.download_outlined,
                  title: 'Exporter mes données',
                  subtitle: 'Reçois un fichier JSON par email',
                  onTap: _isExporting ? null : _exportData,
                  trailing: _isExporting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : null,
                ),
                const Divider(height: 1),
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.06),
                    borderRadius: AppRadius.md,
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.shield_outlined, size: 16, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tes données de santé mentale sont chiffrées et ne sont jamais vendues.',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.delete_outline,
                  title: 'Supprimer mon compte',
                  subtitle: 'Action irréversible — toutes tes données seront effacées',
                  titleColor: AppColors.accent,
                  iconColor: AppColors.accent,
                  onTap: _showDeleteAccountDialog,
                ),
              ]),

              // ── À propos ──────────────────────────────────────────────────
              const _SectionHeader('À propos'),
              _SettingCard(children: [
                _SettingRow(
                  icon: Icons.description_outlined,
                  title: 'Conditions d\'utilisation',
                  onTap: () => context.push('/legal-terms'),
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Politique de confidentialité',
                  onTap: () => _launchUrl('https://basyam.app/legal/privacy'),
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.support_outlined,
                  title: 'Nous contacter',
                  subtitle: 'support@basyam.app',
                  onTap: () => _launchUrl('mailto:support@basyam.app'),
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.chat_bubble_outline,
                  title: 'Support WhatsApp',
                  subtitle: 'Répond sous 24h',
                  onTap: () => _launchUrl(
                      'https://wa.me/22600000000?text=Bonjour%2C%20j%27ai%20besoin%20d%27aide%20avec%20BASYAM.'),
                ),
              ]),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  'BASYAM v1.0.0',
                  style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                ),
              ),
              const SizedBox(height: 40),
            ]),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('Déconnexion'),
        content: const Text('Es-tu sûr(e) de vouloir te déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/auth/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Se déconnecter'),
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
    child: Text(
      title.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
          color: AppColors.onSurfaceMuted,
          fontWeight: FontWeight.w800,
          letterSpacing: .06),
    ),
  );
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
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(children: children),
  );
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  subtitle;
  final VoidCallback? onTap;
  final Color?   titleColor;
  final Color?   iconColor;
  final Widget?  trailing;

  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.titleColor,
    this.iconColor,
    this.trailing,
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
    trailing: trailing ??
        (onTap != null
            ? const Icon(Icons.chevron_right,
                size: 18, color: AppColors.onSurfaceMuted)
            : null),
    onTap: onTap,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  );
}