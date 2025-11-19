import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/colors.dart';
import 'constants/text_styles.dart';
import 'providers/app_state_provider.dart';
import 'screens/home_screen.dart';
import 'widgets/onboarding_flow.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Assistify',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryBlue,
            primary: AppColors.primaryBlue,
            secondary: AppColors.accentCoral,
            surface: AppColors.cardBackground,
            error: AppColors.accentCoral,
          ),
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: AppTextStyles.fontFamily,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: AppColors.cardBackground,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: AppTextStyles.buttonLabel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const AppInitializer(),
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
