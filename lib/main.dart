// TODO: Delete ugly text subtitles (make it a setting)
// TODO: Find way to screen record even outside of app
// TODO: Implement screenshot input into LLM API
// TODO: Prompt engineer better base prompt using README doc
// TODO: Prompt engineer output formatting for better TTS quality
// TODO: Turn conversation history into RAG

// FIXME: Check other promised features to implement
// FIXME: Make sure microphone turns back on, even in the background
// FIXME: Replace Gemini with Baidu ERNIE

// TODO: Open privacy policy
// TODO: Open terms of service
// TODO: Open feedback form

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
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
