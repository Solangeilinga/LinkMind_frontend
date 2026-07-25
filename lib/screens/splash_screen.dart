// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Aucun timer fixe — on navigue dès que l'auth est résolue.
    // ref.listen est attaché dans build(), donc on attend juste
    // que le premier build ait lieu.
  }

  void _navigate(bool isAuthenticated) {
    if (!mounted) return;
    context.go(isAuthenticated ? '/home' : '/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    // Naviguer dès que isLoading passe à false, sans délai artificiel
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (!next.isLoading) {
        _navigate(next.isAuthenticated);
      }
    });

    // Aussi vérifier l'état courant au premier build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (!auth.isLoading && mounted) _navigate(auth.isAuthenticated);
    });

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: AppRadius.xl,
              ),
              child: ClipRRect(
                borderRadius: AppRadius.xl,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('BASYAM',
                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Where Minds Connect',
                style: AppTextStyles.body.copyWith(color: Colors.white70)),
            const SizedBox(height: 60),
            if (authState.isLoading)
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}