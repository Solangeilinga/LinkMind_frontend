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
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (!auth.isLoading) {
      context.go(auth.isAuthenticated ? '/home' : '/auth/login');
    } else {
      // Wait for auth to finish
      ref.listenManual(authProvider, (_, next) {
        if (!next.isLoading && mounted) {
          context.go(next.isAuthenticated ? '/home' : '/auth/login');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: AppRadius.xl,
              ),
              child: const Center(child: Text('🧠', style: TextStyle(fontSize: 56))),
            ),
            const SizedBox(height: 20),
            Text('LinkMind',
                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Where Minds Connect',
                style: AppTextStyles.body.copyWith(color: Colors.white70)),
            const SizedBox(height: 60),
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

