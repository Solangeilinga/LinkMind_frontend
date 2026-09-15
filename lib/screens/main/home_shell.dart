import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/professionals_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/quick_tour_overlay.dart';

class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = [
    _NavItem('/home', Icons.mood_outlined, Icons.mood, 'Mood'),
    _NavItem('/community', Icons.people_outline, Icons.people, 'Hub'),
    _NavItem('/professionals', Icons.medical_services_outlined, Icons.medical_services, 'Pros'),
    _NavItem('/challenges', Icons.bolt_outlined, Icons.bolt, 'Défis'),
    _NavItem('/profile', Icons.person_outline, Icons.person, 'Profil'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Charger les données dynamiques (moods, types pros)
      ref.read(contentProvider.notifier).load();
      // Enregistrer le callback de kick session
      ref.read(authProvider.notifier).setSessionReplacedCallback(() {
        if (mounted) _showSessionReplacedDialog();
      });
      if (mounted) maybeShowQuickTour(context);
    });
  }

  void _showSessionReplacedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Row(children: [
          Text('📵', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Expanded(child: Text('Connexion détectée ailleurs')),
        ]),
        content: const Text(
          'Ton compte a été connecté sur un autre appareil. '
          'Pour protéger tes données, tu as été déconnecté(e) de cet appareil.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/auth/login');
            },
            child: const Text('Se reconnecter'),
          ),
        ],
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => t.path == loc);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.divider, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // Vider le cache des données dynamiques au changement d'onglet
                      final api = ref.read(apiServiceProvider);
                      if (tab.path == '/professionals') {
                        ref.read(professionalsProvider.notifier).loadProfessionals(forceRefresh: true);
                        ref.read(professionalsProvider.notifier).loadBookings(forceRefresh: true);
                      } else if (tab.path == '/home') {
                        api.invalidateCache('/mood/today');
                      } else if (tab.path == '/community') {
                        api.invalidateCache('/community/');
                      } else if (tab.path == '/challenges') {
                        api.invalidateCache('/challenges/');
                      }
                      context.go(tab.path);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary.withValues(alpha: 0.16) : Colors.transparent,
                            borderRadius: AppRadius.md,
                            border: isActive
                                ? Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1)
                                : null,
                          ),
                          child: Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: AppTextStyles.caption.copyWith(
                            color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.path, this.icon, this.activeIcon, this.label);
}