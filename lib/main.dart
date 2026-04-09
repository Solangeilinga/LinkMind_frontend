import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'utils/theme.dart';
import 'utils/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/legal/legal_onboarding_screen.dart';
import 'screens/main/home_shell.dart';
import 'screens/main/mood_screen.dart';
import 'screens/main/challenges_screen.dart';
import 'screens/main/community/community_screen.dart';
import 'screens/main/professionals_screen.dart';
import 'screens/main/profile_screen.dart';
import 'screens/main/assistant_screen.dart';
import 'screens/main/settings_screen.dart';
import 'screens/detail/challenge_detail_screen.dart';
import 'screens/detail/mood_history_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/app_settings_provider.dart';
import 'services/security.service.dart';
import 'services/local_notification_service.dart';
import 'services/api.service.dart';
import 'firebase_options.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/auth/verify_email_screen.dart';  // ✅ AJOUTÉ

// Handler pour les messages en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Message background: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialisé avec succès');
  } catch (e) {
    debugPrint('❌ Erreur Firebase: $e');
  }

  // Configurer Firebase Messaging
  try {
    await setupFirebaseMessaging();
  } catch (e) {
    debugPrint('❌ Erreur setup Firebase Messaging: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await LocalNotificationService.init();
    await LocalNotificationService.setupAllReminders();
  } catch (e) {
    debugPrint('Erreur d\'initialisation des notifications: $e');
  }

  runApp(const ProviderScope(child: LinkMindApp()));
}

Future<void> setupFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('✅ Permission FCM accordée');

    String? token = await messaging.getToken();
    debugPrint('📱 FCM Token: $token');

    if (token != null) {
      await ApiService().registerFcmToken(token);
    }
  } else {
    debugPrint('❌ Permission FCM refusée');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('📨 Message reçu: ${message.notification?.title}');
    LocalNotificationService.showNotification(
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📨 Notification cliquée: ${message.notification?.title}');
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

class LinkMindApp extends ConsumerStatefulWidget {
  const LinkMindApp({super.key});
  @override
  ConsumerState<LinkMindApp> createState() => _LinkMindAppState();
}

class _LinkMindAppState extends ConsumerState<LinkMindApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          SecurityService.init(context);
        } catch (e) {
          debugPrint('Erreur SecurityService.init: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      SecurityService.dispose();
    } catch (e) {
      debugPrint('Erreur SecurityService.dispose: $e');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        SecurityService.refreshSession();
        LocalNotificationService.setupAllReminders();
      } catch (e) {
        debugPrint('Erreur dans didChangeAppLifecycleState: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final settings = ref.watch(appSettingsProvider);

    final router = GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) async {
        final loc = state.matchedLocation;
        final isLoggedIn = authState.isAuthenticated;
        final isAuthRoute = loc.startsWith('/auth');
        final isSplash = loc == '/splash';
        final isForgotPwd = loc == '/auth/forgot-password';
        final isOnboarding = loc == '/onboarding';
        final isLegalOnboarding = loc == '/legal-onboarding';
        final isVerifyEmail = loc == '/verify-email';  // ✅ AJOUTÉ

        // 🔴 1. Écran Splash
        if (isSplash) return null;

        // 🔴 2. Utilisateur NON connecté
        if (!isLoggedIn) {
          // Routes autorisées sans connexion
          if (isAuthRoute || isOnboarding || isLegalOnboarding || isVerifyEmail) return null;
          
          // Vérifier si onboarding déjà fait
          final prefs = await SharedPreferences.getInstance();
          final onboardingDone = prefs.getBool('onboarding_done') ?? false;
          
          if (!onboardingDone) return '/onboarding';
          return '/auth/login';
        }

        // 🔴 3. Utilisateur connecté
        if (isLoggedIn) {
          // ✅ Ne pas rediriger si déjà sur legal-onboarding ou verify-email
          if (isLegalOnboarding || isVerifyEmail) return null;
          
          // ✅ Vérifier si les CGU sont acceptées
          final user = authState.user;
          if (user != null && user.legalAccepted != true) {
            return '/legal-onboarding';
          }
          
          // ✅ Rediriger les routes auth vers home
          if (isAuthRoute && !isForgotPwd) return '/home';
          
          // ✅ Rediriger onboarding si déjà connecté
          if (isOnboarding) return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(
          path: '/onboarding', 
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/legal-onboarding',
          builder: (_, __) => const LegalOnboardingScreen(),
        ),
        GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/auth/register', 
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/auth/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/verify-email',  // ✅ NOUVEAU
          builder: (_, __) => const VerifyEmailScreen(),
        ),
        GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),
        ShellRoute(
          builder: (context, state, child) => HomeShell(child: child),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const MoodScreen()),
            GoRoute(
              path: '/challenges',
              builder: (_, __) => const ChallengesScreen(),
            ),
            GoRoute(
              path: '/assistant',
              builder: (_, __) => const AssistantScreen(),
            ),
            GoRoute(
              path: '/community',
              builder: (_, __) => const CommunityScreen(),
            ),
            GoRoute(
              path: '/professionals',
              builder: (_, __) => const ProfessionalsScreen(),
            ),
            GoRoute(
              path: '/profile', 
              builder: (_, __) => const ProfileScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/challenges/:id',
          builder: (context, state) => ChallengeDetailScreen(
            challengeId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/mood/history',
          builder: (_, __) => const MoodHistoryScreen(),
        ),
        GoRoute(
          path: '/settings', 
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.textScale.clamp(0.8, 1.5)),
          ),
          child: child,
        );
      },
      routerConfig: router,
    );
  }
}