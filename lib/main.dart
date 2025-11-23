// TODO: Improve prompt engineering for better personality and responses
//       Should be aware of its own features + limitations,
//       note when screen capture ends, etc.
// FIXME: Talking to itself + doesn't handle start screen share gracefully

// TODO: Replace Gemini with Baidu ERNIE (must test!)
// TODO: Need to fine tune model?

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/colors.dart';
import 'constants/theme.dart';
import 'providers/app_state_provider.dart';
import 'screens/home_screen.dart';
import 'widgets/onboarding_flow.dart';
import 'utils/localization_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl != null &&
      supabaseUrl != 'your_supabase_url_here' &&
      supabaseAnonKey != null &&
      supabaseAnonKey != 'your_supabase_anon_key_here') {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const AssistifyApp());
}

class AssistifyApp extends StatelessWidget {
  const AssistifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          final locale = LocalizationHelper.getLocaleFromPreferences(
            appState.preferences,
          );

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Assistify',
            locale: locale,
            supportedLocales: LocalizationHelper.supportedLocales,
            localizationsDelegates: LocalizationHelper.localizationDelegates,
            theme: appState.preferences.highContrastEnabled
                ? AppTheme.highContrast
                : AppTheme.standard,
            builder: (context, child) {
              // Apply text scaling based on user preferences
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(
                    appState.preferences.textScaleFactor,
                  ),
                ),
                child: child!,
              );
            },
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

/// App initializer that handles initial setup and onboarding
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    // Initialize app state from storage
    await appState.initialize();

    setState(() {
      _isInitialized = true;
    });

    // Show onboarding flow if needed
    if (!appState.hasCompletedOnboarding && mounted) {
      // Wait a frame to ensure widget tree is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          OnboardingFlow.show(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show loading screen while initializing
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    return const HomeScreen();
  }
}
