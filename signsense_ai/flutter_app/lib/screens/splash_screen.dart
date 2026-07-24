import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/voice_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Brief pause so the splash animation is visible before TTS starts.
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      final voice = context.read<VoiceProvider>();
      await voice.speak(
        'Welcome to SignSense AI. Your Universal Accessibility Assistant. Loading...',
      );
    }

    // Allow the loading animation and TTS to complete.
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      final isFirstLaunch = await _checkFirstLaunch();
      if (isFirstLaunch) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }
  }

  /// Returns true when this is genuinely the first app launch.
  ///
  /// Fix (Module 1): The original implementation always returned `true`,
  /// meaning onboarding was shown on every single launch — including
  /// after the user had completed it and returned to the app.
  ///
  /// Now reads the 'isFirstLaunch' SharedPreferences key that is written
  /// by [AppProvider.setFirstLaunchComplete()] when the user taps
  /// "Get Started" on the onboarding screen.
  Future<bool> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    // Key matches what AppProvider writes: prefs.setBool('isFirstLaunch', false)
    return prefs.getBool('isFirstLaunch') ?? true;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.05),
                    child: child,
                  );
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.ibmBlue,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.ibmBlue.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.visibility_outlined,
                    size: 70,
                    color: Colors.white,
                    semanticLabel: 'SignSense AI Eye Logo',
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 32),

              // App Name
              const Text(
                'SignSense AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms),

              const SizedBox(height: 8),

              // Tagline
              const Text(
                'Universal Accessibility Assistant',
                style: TextStyle(
                  color: AppTheme.ibmCoolGray,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms),

              const SizedBox(height: 16),

              // IBM SkillsBuild Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.ibmBlue),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'IBM SkillsBuild Project',
                  style: TextStyle(
                    color: AppTheme.ibmBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 600.ms),

              const SizedBox(height: 60),

              // Loading indicator
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.surfaceDark,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.ibmBlue),
                  minHeight: 2,
                ),
              )
                  .animate()
                  .fadeIn(delay: 900.ms, duration: 400.ms),

              const SizedBox(height: 16),

              const Text(
                'Empowering the visually impaired...',
                style: TextStyle(
                  color: AppTheme.ibmCoolGray,
                  fontSize: 13,
                ),
              )
                  .animate()
                  .fadeIn(delay: 1100.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
