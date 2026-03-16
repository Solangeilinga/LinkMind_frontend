import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    _NavItem('/home', Icons.mood_outlined, Icons.mood, 'Humeur'),
    _NavItem('/assistant', Icons.psychology_outlined, Icons.psychology, 'Mindo'),
    _NavItem('/community', Icons.people_outline, Icons.people, 'Communauté'),
    _NavItem('/challenges', Icons.bolt_outlined, Icons.bolt, 'Défis'),
    _NavItem('/profile', Icons.person_outline, Icons.person, 'Profil'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => t.path == loc);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
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
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;
                final isMindo = tab.path == '/assistant';

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go(tab.path),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isMindo ? 52 : 46,
                          height: isMindo ? 36 : 32,
                          decoration: BoxDecoration(
                            color: isActive && isMindo
                                ? AppColors.primary
                                : isActive && !isMindo
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                            borderRadius: isMindo ? AppRadius.lg : AppRadius.md,
                            border: !isActive && isMindo
                                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)
                                : null,
                          ),
                          child: isMindo
                              ? Center(
                                  child: Text('🧠',
                                      style: TextStyle(fontSize: isActive ? 22 : 18)))
                              : Icon(
                                  isActive ? tab.activeIcon : tab.icon,
                                  color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
                                  size: 22,
                                ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: AppTextStyles.caption.copyWith(
                            color: isActive
                                ? (isMindo ? AppColors.primary : AppColors.primary)
                                : AppColors.onSurfaceMuted,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 10,
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