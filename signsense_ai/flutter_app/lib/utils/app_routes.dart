import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/camera_screen.dart';
import '../screens/navigation_screen.dart';
import '../screens/ocr_screen.dart';
import '../screens/scene_description_screen.dart';
import '../screens/currency_screen.dart';
import '../screens/sos_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/history_screen.dart';
import '../screens/blind_mode_screen.dart';
import '../screens/deaf_mode_screen.dart';
import '../screens/object_detection_screen.dart';
import '../screens/sign_language_detection_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String camera = '/camera';
  static const String navigation = '/navigation';
  static const String ocr = '/ocr';
  static const String sceneDescription = '/scene-description';
  static const String currency = '/currency';
  static const String sos = '/sos';
  static const String settings = '/settings';
  static const String history = '/history';

  // Phase C — Blind AI Voice Mode (full-screen voice-first AI loop)
  static const String blindMode = '/blind-mode';

  // Phase E — Deaf & Mute Communication Mode (sign language → text/voice)
  static const String deafMode = '/deaf-mode';

  // New separate feature screens
  static const String objectDetection = '/object-detection';
  static const String signLanguageDetection = '/sign-language-detection';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _buildRoute(const SplashScreen(), settings);
      case onboarding:
        return _buildRoute(const OnboardingScreen(), settings);
      case home:
        return _buildRoute(const HomeScreen(), settings);
      case camera:
        return _buildRoute(const CameraScreen(), settings);
      case navigation:
        return _buildRoute(const NavigationScreen(), settings);
      case ocr:
        return _buildRoute(const OCRScreen(), settings);
      case sceneDescription:
        return _buildRoute(const SceneDescriptionScreen(), settings);
      case currency:
        return _buildRoute(const CurrencyScreen(), settings);
      case sos:
        return _buildRoute(const SOSScreen(), settings);
      case AppRoutes.settings:
        return _buildRoute(const SettingsScreen(), settings);
      case history:
        return _buildRoute(const HistoryScreen(), settings);
      case blindMode:
        return _buildRoute(const BlindModeScreen(), settings);
      case deafMode:
        return _buildRoute(const DeafModeScreen(), settings);
      case objectDetection:
        return _buildRoute(const ObjectDetectionScreen(), settings);
      case signLanguageDetection:
        return _buildRoute(const SignLanguageDetectionScreen(), settings);
      default:
        return _buildRoute(const HomeScreen(), settings);
    }
  }

  static PageRouteBuilder _buildRoute(
      Widget page, RouteSettings routeSettings) {
    return PageRouteBuilder(
      settings: routeSettings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
            position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
