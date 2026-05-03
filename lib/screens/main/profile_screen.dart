import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart'; // ✅ Import correct ici
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api.service.dart';
import '../../models/models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<Map<String, dynamic>> _allBadges = [];
  bool _exportingReport = false;
  String? _reportPath;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      final data = await ApiService().getMe();
      if (mounted) {
        setState(() {
          _allBadges = List<Map<String, dynamic>>.from(data['badges'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _exportReport() async {
    setState(() => _exportingReport = true);
    try {
      final token = await ApiService().getAccessToken();
      final baseUrl = AppConstants.baseUrl;
      final dio = Dio();
      final dir = await getTemporaryDirectory();
      final date = DateTime.now().toIso8601String().split('T')[0];
      final path = '${dir.path}/linkmind-rapport-$date.pdf';

      await dio.download(
        '$baseUrl/users/me/report',
        path,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Fichier PDF invalide ou vide');
      }

      if (mounted) {
        setState(() {
          _exportingReport = false;
          _reportPath = path;
        });
        _showSuccessDialog(path);
      }
    } catch (e) {
      debugPrint('❌ Erreur export: $e');
      if (mounted) {
        setState(() => _exportingReport = false);
        _showErrorSnackBar('Erreur lors de la génération du rapport : ${e.toString()}');
      }
    }
  }

  void _showSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.secondary, size: 28),
            SizedBox(width: 8),
            Text('Rapport prêt !'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ton rapport PDF a été généré avec succès.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: AppColors.primary),
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
                _showErrorSnackBar('Impossible d\'ouvrir le fichier : ${result.message}');
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Ouvrir le PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showEditSheet() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: user,
        onSaved: (updated) {
          ref.read(authProvider.notifier).updateUser(updated);
          _showSuccessSnackBar('Profil mis à jour avec succès');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mon profil', style: AppTextStyles.h2),
                    IconButton(
                      onPressed: _showEditSheet,
                      icon: const Icon(Icons.edit_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileCard(user),
                    const SizedBox(height: 20),
                    _buildStatsSection(user),
                    const SizedBox(height: 24),
                    if (user.email != null || user.phone != null)
                      _buildContactSection(user),
                    _buildProgressSection(user),
                    const SizedBox(height: 24),
                    _buildBadgesSection(),
                    const SizedBox(height: 24),
                    _buildActionsSection(user),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.lg,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.anonymousAlias != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: AppRadius.full,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎭', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          user.anonymousAlias!,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (user.city != null || user.age != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (user.city != null) ...[
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.city!,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      if (user.city != null && user.age != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('•', style: TextStyle(color: Colors.white54)),
                        ),
                      if (user.age != null)
                        Text(
                          '${user.age} ans',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ],
                if (user.isPremium) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: AppRadius.full,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👑', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text(
                          'PREMIUM',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('⚡', '${user.totalPoints}', 'Points'),
          _buildStatItem('🔥', '${user.streakDays}', 'Jours'),
          _buildStatItem('🏅', user.levelLabel, 'Niveau'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.h4.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (user.email != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                user.email!,
                style: AppTextStyles.body,
              ),
              subtitle: Text(
                'Email',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
          if (user.email != null && user.phone != null)
            const Divider(height: 1),
          if (user.phone != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  color: AppColors.secondary,
                  size: 20,
                ),
              ),
              title: Text(
                user.phone!,
                style: AppTextStyles.body,
              ),
              subtitle: Text(
                'Téléphone',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progression', style: AppTextStyles.h4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  'Niveau ${user.levelLabel}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.full,
                child: LinearProgressIndicator(
                  value: user.levelProgress / 100,
                  backgroundColor: AppColors.divider,
                  color: AppColors.primary,
                  minHeight: 10,
                ),
              ),
              Positioned(
                right: 0,
                bottom: -18,
                child: Text(
                  '${user.totalPoints} pts',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${user.levelProgress}% vers le prochain niveau',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  bool _showAllBadges = false;
  static const _badgesPreviewCount = 8;

  Widget _buildBadgesSection() {
    final earnedBadges = _allBadges.where((b) => b['earned'] == true).toList();
    final totalEarned = earnedBadges.length;
    final totalAll = _allBadges.length;
    final displayedBadges = _showAllBadges
        ? earnedBadges
        : earnedBadges.take(_badgesPreviewCount).toList();
    final hasMore = earnedBadges.length > _badgesPreviewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mes badges', style: AppTextStyles.h3),
            Text(
              '$totalEarned/$totalAll débloqués',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (earnedBadges.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.lg,
            ),
            child: Column(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(
                  'Aucun badge encore',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enregistre ton humeur, complète des défis\net participe à la communauté pour gagner tes premiers badges !',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: displayedBadges.length,
            itemBuilder: (ctx, index) {
              return _buildBadgeItem(displayedBadges[index], true);
            },
          ),
          if (hasMore) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showAllBadges = !_showAllBadges),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAllBadges
                          ? 'Voir moins'
                          : 'Voir tous les badges (${earnedBadges.length - _badgesPreviewCount} de plus)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showAllBadges ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBadgeItem(Map<String, dynamic> badge, bool earned) {
    return Opacity(
      opacity: earned ? 1.0 : 0.4,
      child: Container(
        decoration: BoxDecoration(
          color: earned
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: earned
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.divider.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              badge['icon'] ?? '🏅',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              badge['name'] ?? '',
              style: AppTextStyles.caption.copyWith(
                color: earned ? AppColors.onSurface : AppColors.onSurfaceMuted,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(UserModel user) {
    return Column(
      children: [
        if (user.isPremium)
          Container(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _exportingReport ? null : _exportReport,
              icon: _exportingReport
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                _exportingReport
                    ? 'Génération en cours...'
                    : 'Exporter mon rapport PDF',
                style: AppTextStyles.button,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.md,
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                _showPremiumDialog();
              },
              icon: const Text('👑', style: TextStyle(fontSize: 16)),
              label: const Text(
                'Débloquer les rapports PDF',
                style: AppTextStyles.button,
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.md,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (!user.isPremium)
          Container(
            width: double.infinity,
            height: 52,
            margin: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/premium'),
              icon: const Text('👑', style: TextStyle(fontSize: 16)),
              label: const Text('Passer en Premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Paramètres', style: AppTextStyles.button),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.divider),
              foregroundColor: AppColors.onSurface,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _showLogoutDialog(),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Se déconnecter',
              style: AppTextStyles.button,
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accent),
              foregroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.md,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Row(
          children: [
            Text('👑', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Fonctionnalité Premium'),
          ],
        ),
        content: const Text(
          'Les rapports PDF détaillés sont réservés aux membres Premium. '
          'Passe à Premium pour débloquer cette fonctionnalité et bien plus !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Naviguer vers l'écran Premium
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Voir les offres'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('Déconnexion'),
        content: const Text('Es-tu sûr de vouloir te déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/auth/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Profile Sheet ──────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final UserModel user;
  final Function(UserModel) onSaved;
  const _EditProfileSheet({required this.user, required this.onSaved});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _aliasCtrl;
  late final TextEditingController _currentPassCtrl;
  late final TextEditingController _newPassCtrl;
  late final TextEditingController _ageCtrl;

  String? _gender;
  bool _saving = false;
  bool _showPassSection = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _error;
  String? _success;

  static const _genders = [
    ('homme', '👨 Homme'),
    ('femme', '👩 Femme'),
    ('non_specifie', '— Préfère ne pas préciser'),
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _firstNameCtrl = TextEditingController(text: u.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: u.lastName ?? '');
    _emailCtrl = TextEditingController(text: u.email ?? '');
    _phoneCtrl = TextEditingController(text: u.phone ?? '');
    _cityCtrl = TextEditingController(text: u.city ?? '');
    _aliasCtrl = TextEditingController(text: u.anonymousAlias ?? '');
    _ageCtrl = TextEditingController(text: u.age != null ? '${u.age}' : '');
    _currentPassCtrl = TextEditingController();
    _newPassCtrl = TextEditingController();
    _gender = u.gender;
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _cityCtrl,
      _aliasCtrl,
      _ageCtrl,
      _currentPassCtrl,
      _newPassCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Prénom et nom sont obligatoires');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      final data = await ApiService().updateProfile({
        'firstName': firstName,
        'lastName': lastName,
        'name': '$firstName $lastName',
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'anonymousAlias':
            _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
        if (_ageCtrl.text.trim().isNotEmpty)
          'age': int.tryParse(_ageCtrl.text.trim()),
        if (_gender != null) 'gender': _gender,
      });

      final updated = UserModel.fromJson(data['user']);
      widget.onSaved(updated);
      
      if (mounted) {
        setState(() {
          _saving = false;
          _success = 'Profil mis à jour avec succès !';
        });
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Une erreur est survenue';
        });
      }
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    
    if (current.isEmpty || newPass.isEmpty) {
      setState(() => _error = 'Remplis les deux champs');
      return;
    }
    
    if (newPass.length < 6) {
      setState(() =>
          _error = 'Le nouveau mot de passe doit faire au moins 6 caractères');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      await ApiService().patch('/auth/change-password', {
        'currentPassword': current,
        'newPassword': newPass,
      });

      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      
      if (mounted) {
        setState(() {
          _saving = false;
          _success = 'Mot de passe modifié avec succès !';
          _showPassSection = false;
        });
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _success = null;
            });
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Une erreur est survenue';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: AppRadius.full,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Modifier le profil',
                    style: AppTextStyles.h3,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_success != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _success!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text('Identité', style: AppTextStyles.h4),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Prénom *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Contact', style: AppTextStyles.h4),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Infos personnelles', style: AppTextStyles.h4),
              const SizedBox(height: 12),
              TextField(
                controller: _cityCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ville',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Âge',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text('Genre', style: AppTextStyles.body),
              ..._genders.map((g) => RadioListTile<String>(
                value: g.$1,
                groupValue: _gender,
                onChanged: (v) => setState(() => _gender = v),
                title: Text(g.$2),
                dense: true,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              )),
              const SizedBox(height: 16),
              Text('Communauté', style: AppTextStyles.h4),
              const SizedBox(height: 12),
              TextField(
                controller: _aliasCtrl,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Pseudo anonyme',
                  hintText: 'Ex: 🌙 Lune curieuse',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPassSection = !_showPassSection;
                    _error = null;
                  });
                },
                icon: Icon(_showPassSection ? Icons.expand_less : Icons.expand_more),
                label: Text(
                  _showPassSection ? 'Masquer' : 'Changer le mot de passe',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              if (_showPassSection) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _currentPassCtrl,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe actuel',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Mettre à jour le mot de passe'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}