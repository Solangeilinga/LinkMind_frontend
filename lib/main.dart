import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'utils/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/main/home_shell.dart';
import 'screens/main/mood_screen.dart';
import 'screens/main/challenges_screen.dart';
import 'screens/main/community_screen.dart';
import 'screens/main/profile_screen.dart';
import 'screens/main/assistant_screen.dart';
import 'screens/detail/challenge_detail_screen.dart';
import 'screens/detail/mood_history_screen.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const ProviderScope(child: LinkMindApp()));
}

class LinkMindApp extends ConsumerWidget {
  const LinkMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final router = GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final isLoggedIn = authState.isAuthenticated;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        final isSplash = state.matchedLocation == '/splash';

        final isForgotPassword = state.matchedLocation == '/auth/forgot-password';

        if (isSplash) return null;
        if (!isLoggedIn && !isAuthRoute) return '/auth/login';
        // Autoriser forgot-password même si connecté
        if (isLoggedIn && isAuthRoute && !isForgotPassword) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/auth/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
        ShellRoute(
          builder: (context, state, child) => HomeShell(child: child),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const MoodScreen()),
            GoRoute(path: '/challenges', builder: (_, __) => const ChallengesScreen()),
            GoRoute(path: '/assistant', builder: (_, __) => const AssistantScreen()),
            GoRoute(path: '/community', builder: (_, __) => const CommunityScreen()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ],
        ),
        GoRoute(
          path: '/challenges/:id',
          builder: (context, state) => ChallengeDetailScreen(
            challengeId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(path: '/mood/history', builder: (_, __) => MoodHistoryScreen()),

      ],
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}