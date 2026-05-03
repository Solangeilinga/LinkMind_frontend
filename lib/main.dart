import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Utils & Theme
import 'utils/theme.dart';
import 'utils/app_localizations.dart';

// Services
import 'services/local_notification_service.dart';
import 'services/security.service.dart';
import 'services/api.service.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
// import 'screens/legal/legal_onboarding_screen.dart'; // ← Plus nécessaire
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
import 'screens/premium/premium_screen.dart';
import 'screens/legal/legal_terms_screen.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/app_settings_provider.dart';

// Firebase
import 'firebase_options.dart';

// ✅ Provider pour SharedPreferences (préchargé une fois)
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// ✅ Handler pour messages background FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Message background: ${message.notification?.title}');
}

void main() async {
  // ✅ 1. Initialisation Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 2. Configuration orientation (portrait uniquement)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ✅ 3. Style de la barre d'état
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // ✅ 4. Initialisation Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialisé');
  } catch (e) {
    debugPrint('❌ Erreur Firebase: $e');
  }

  // ✅ 5. Configuration Firebase Messaging
  try {
    await _setupFirebaseMessaging();
  } catch (e) {
    debugPrint('❌ Erreur FCM: $e');
  }

  // ✅ 6. Initialisation notifications locales
  try {
    await LocalNotificationService.init();
    await LocalNotificationService.setupAllReminders();
    debugPrint('✅ Notifications locales initialisées');
  } catch (e) {
    debugPrint('❌ Erreur notifications: $e');
  }

  // ✅ 7. Lancement de l'app
  runApp(const ProviderScope(child: LinkMindApp()));
}

Future<void> _setupFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  // Demander les permissions
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('✅ Permission FCM accordée');

    // Récupérer et enregistrer le token
    String? token = await messaging.getToken();
    debugPrint('📱 FCM Token: $token');

    if (token != null) {
      await ApiService().registerFcmToken(token);
    }
  } else {
    debugPrint('❌ Permission FCM refusée');
  }

  // Écouter les messages en premier plan
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('📨 Message reçu: ${message.notification?.title}');
    LocalNotificationService.showNotification(
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
    );
  });

  // Écouter les clics sur notifications
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📨 Notification cliquée: ${message.notification?.title}');
  });

  // Handler background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

class LinkMindApp extends ConsumerStatefulWidget {
  const LinkMindApp({super.key});

  @override
  ConsumerState<LinkMindApp> createState() => _LinkMindAppState();
}

class _LinkMindAppState extends ConsumerState<LinkMindApp>
    with WidgetsBindingObserver {
  
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = _buildRouter();
    
    // Initialiser SecurityService après le premier frame
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
        debugPrint('Erreur lifecycle: $e');
      }
    }
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/init',
      debugLogDiagnostics: false,
      redirect: (context, state) async {
        final location = state.matchedLocation;
        final authState = ref.read(authProvider);
        final isLoggedIn = authState.isAuthenticated;
        
        // Routes spéciales
        final isInit = location == '/init';
        final isAuthRoute = location.startsWith('/auth');
        final isForgotPassword = location == '/auth/forgot-password';
        final isOnboarding = location == '/onboarding';
        final isVerifyEmail = location == '/verify-email';
        final isLegalTerms = location == '/legal-terms'; // ← Ajout

        // /init : point d'entrée — redirige immédiatement selon l'état
        if (isInit) {
          final prefs = await ref.read(sharedPrefsProvider.future);
          final onboardingDone = prefs.getBool('onboarding_done') ?? false;
          if (!isLoggedIn) {
            return onboardingDone ? '/auth/login' : '/onboarding';
          }
          // Connecté : le reste du redirect gère home/onboarding
          return null;
        }
        
        // 2. Utilisateur NON connecté
        if (!isLoggedIn) {
          // Routes autorisées sans connexion
          if (isAuthRoute || isOnboarding || isVerifyEmail || isLegalTerms) {
            return null;
          }
          
          // Utiliser les préférences préchargées (une seule attente)
          final prefs = await ref.read(sharedPrefsProvider.future);
          final onboardingDone = prefs.getBool('onboarding_done') ?? false;

          if (!onboardingDone) return '/onboarding';
          return '/auth/login';
        }
        
        // 3. Utilisateur connecté
        if (isLoggedIn) {
          // Ne pas rediriger sur ces écrans
          if (isVerifyEmail) return null;

          // Autoriser l'onboarding si c'est un nouvel inscrit (flag SharedPrefs)
          if (isOnboarding) {
            final prefs = await ref.read(sharedPrefsProvider.future);
            final needsOnboarding = prefs.getBool('needs_onboarding') ?? false;
            if (needsOnboarding) return null; // laisser passer
            return '/home'; // déjà fait
          }

          final user = ref.read(authProvider).user;

          // Si l'email n'est pas encore vérifié → forcer /verify-email
          if (user != null && user.isEmailVerified != true && user.email != null) {
            return '/verify-email';
          }

          // Plus de vérification legalAccepted ici (faite à l'inscription)
          // Rediriger les routes d'auth (sauf forgot-password)
          if (isAuthRoute && !isForgotPassword) return '/home';
        }
        
        return null;
      },
      routes: [
        // Écran de démarrage
        GoRoute(
          path: '/init',
          builder: (_, __) => const _SplashLoader(),
        ),
        
        // Onboarding
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        
        // Authentification
        GoRoute(
          path: '/auth/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/auth/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (_, __) => const VerifyEmailScreen(),
        ),
        
        // Conditions générales (accessible sans connexion)
        GoRoute(
          path: '/legal-terms',
          builder: (_, __) => const LegalTermsScreen(),
        ),
        
        // Premium
        GoRoute(
          path: '/premium',
          builder: (_, __) => const PremiumScreen(),
        ),
        
        // Structure principale avec BottomNavigationBar
        ShellRoute(
          builder: (context, state, child) => HomeShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const MoodScreen(),
            ),
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
        
        // Écrans de détail
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
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final settings = ref.watch(appSettingsProvider);

    // Notifier le router que l'état auth a changé
    _router.refresh();

    // Pendant le chargement initial de l'auth, afficher le splash
    if (authState.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode,
        home: const _SplashLoader(),
      );
    }

    return MaterialApp.router(
      title: 'LinkMind',
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
      routerConfig: _router,
    );
  }
}

// ─── Splash Loader (branding visuel, sans timer) ──────────────────────────────
// Affiché uniquement pendant le chargement initial de l'auth (quelques ms)
class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
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
            Text(
              'LinkMind',
              style: AppTextStyles.h1.copyWith(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Where Minds Connect',
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 60),
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}