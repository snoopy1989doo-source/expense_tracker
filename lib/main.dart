import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/onboarding_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/guided_onboarding_screen.dart';
import 'screens/dashboard/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Gracefully initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // If Firebase initialization fails (no configuration files or services),
    // the repositories are built to fallback gracefully to mock local storage.
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkTheme = ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);
    final onboardingCompleted = ref.watch(onboardingCompletedProvider);

    return MaterialApp(
      title: 'ถุงเงินคู่รัก',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      
      // Setup Thai localizations for calendar date formatting
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'),
        Locale('en', 'US'),
      ],
      locale: const Locale('th', 'TH'),

      home: authState.when(
        data: (userId) {
          if (userId == null) {
            return const LoginScreen();
          } else {
            if (onboardingCompleted) {
              return const MainNavigationScreen();
            } else {
              return const GuidedOnboardingScreen();
            }
          }
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Text('เกิดข้อผิดพลาดในการโหลดระบบ: $err'),
          ),
        ),
      ),
    );
  }
}
