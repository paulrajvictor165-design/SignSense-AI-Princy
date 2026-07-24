/// SignSense AI — Home Screen
///
/// Phase B redesign — Mode 1 / Mode 2 two-button entry point.
///
/// BEFORE: 8-card feature grid listing every feature independently.
///         No clear conceptual entry-point for users who are blind or deaf.
///
/// AFTER:  Two hero mode buttons as the primary call to action:
///   • Mode 1 — Blind AI Voice Assistant  → /blind-mode
///   • Mode 2 — Deaf & Mute AI Assistant  → /deaf-mode
///
///   A secondary "All Tools" section below shows the full feature grid for
///   users who want direct access (Navigation, OCR, Currency, Scene, SOS,
///   History, Settings) — this preserves the existing feature-card widget and
///   all routes so nothing is removed, only a new top layer is added.
///
/// VoiceFAB voice commands are extended with "blind mode" and "deaf mode".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/voice_provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_routes.dart';
import '../widgets/feature_card.dart';
import '../widgets/voice_fab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceProvider>().speak(
        'SignSense AI. '
        'Two modes available: '
        'Mode one, Blind AI Voice Assistant. '
        'Mode two, Deaf and Mute AI Communication Assistant. '
        'Tap a mode button to begin, or select a tool below.',
      );
    });
  }

  // ── Secondary tools shown below the mode buttons ──────────────────────────

  final List<FeatureItem> _tools = [
    FeatureItem(
      icon: Icons.search_outlined,
      label: 'Object Detection',
      sublabel: 'YOLO · live camera',
      color: AppTheme.ibmBlue,
      route: AppRoutes.objectDetection,
      voiceHint: 'Opens Object Detection with bounding boxes',
    ),
    FeatureItem(
      icon: Icons.sign_language_outlined,
      label: 'Sign Language',
      sublabel: 'Hand landmark · ISL',
      color: AppTheme.ibmPurple,
      route: AppRoutes.signLanguageDetection,
      voiceHint: 'Opens Sign Language Detection',
    ),
    FeatureItem(
      icon: Icons.landscape_outlined,
      label: 'Scene Description',
      sublabel: 'Gemini AI analysis',
      color: AppTheme.ibmTeal,
      route: AppRoutes.sceneDescription,
      voiceHint: 'Opens Gemini AI scene description',
    ),
    FeatureItem(
      icon: Icons.currency_rupee,
      label: 'Currency',
      sublabel: 'Indian currency detect',
      color: AppTheme.ibmYellow,
      route: AppRoutes.currency,
      voiceHint: 'Opens currency detection',
    ),
    FeatureItem(
      icon: Icons.navigation_outlined,
      label: 'Navigation',
      sublabel: 'Smart path guidance',
      color: AppTheme.ibmGreen,
      route: AppRoutes.navigation,
      voiceHint: 'Opens navigation assistant',
    ),
    FeatureItem(
      icon: Icons.document_scanner_outlined,
      label: 'Read Text (OCR)',
      sublabel: 'Books, signs, labels',
      color: const Color(0xFF6929C4),
      route: AppRoutes.ocr,
      voiceHint: 'Opens text reader using camera',
    ),
    FeatureItem(
      icon: Icons.sos_outlined,
      label: 'Emergency SOS',
      sublabel: 'Alert contacts',
      color: AppTheme.ibmRed,
      route: AppRoutes.sos,
      voiceHint: 'Opens emergency SOS screen',
    ),
    FeatureItem(
      icon: Icons.settings_outlined,
      label: 'Settings',
      sublabel: 'Customize experience',
      color: AppTheme.ibmCoolGray,
      route: AppRoutes.settings,
      voiceHint: 'Opens settings',
    ),
  ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                Icons.visibility_outlined,
                size: 20,
                color: AppTheme.ibmBlue,
              ),
            ),
            const SizedBox(width: 10),
            const Text('SignSense AI'),
          ],
        ),
        actions: [
          Semantics(
            label: 'Toggle offline mode',
            child: IconButton(
              icon: Icon(
                appProvider.offlineMode
                    ? Icons.wifi_off_outlined
                    : Icons.wifi_outlined,
              ),
              onPressed: () {
                appProvider.setOfflineMode(!appProvider.offlineMode);
                context.read<VoiceProvider>().speak(
                      appProvider.offlineMode
                          ? 'Offline mode enabled'
                          : 'Online mode enabled',
                    );
              },
              tooltip: 'Toggle Offline Mode',
            ),
          ),
          Semantics(
            label: 'Open settings',
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.settings),
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Offline badge ────────────────────────────────────────────
              if (appProvider.offlineMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.ibmYellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.ibmYellow),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_outlined,
                          size: 14, color: AppTheme.ibmYellow),
                      SizedBox(width: 6),
                      Text(
                        'Offline Mode Active',
                        style: TextStyle(
                          color: AppTheme.ibmYellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Hero prompt ───────────────────────────────────────────────
              Text(
                'Choose your mode',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ).animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 4),
              Text(
                'Select the AI mode that fits your accessibility need.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.ibmCoolGray),
              ).animate().fadeIn(delay: 150.ms, duration: 350.ms),

              const SizedBox(height: 20),

              // ── Mode 1 — Blind AI Voice Assistant ────────────────────────
              _ModeButton(
                index: 0,
                icon: Icons.hearing_outlined,
                title: 'Blind AI Voice Assistant',
                subtitle:
                    'Full-screen voice-first • Object detection • Navigation\n'
                    'OCR • Scene AI • Currency — all announced by voice',
                color: AppTheme.ibmBlue,
                route: AppRoutes.blindMode,
                semanticsLabel:
                    'Mode 1: Blind AI Voice Assistant. '
                    'Full-screen voice-first experience with object detection, '
                    'navigation, text reading, and AI scene description.',
              ),

              const SizedBox(height: 14),

              // ── Mode 2 — Deaf & Mute AI Communication ────────────────────
              _ModeButton(
                index: 1,
                icon: Icons.sign_language_outlined,
                title: 'Deaf & Mute AI Assistant',
                subtitle:
                    'Sign language recognition • Real-time text output\n'
                    'Voice synthesis from signs • ISL support',
                color: AppTheme.ibmPurple,
                route: AppRoutes.deafMode,
                semanticsLabel:
                    'Mode 2: Deaf and Mute AI Communication Assistant. '
                    'Sign language recognition with real-time text and voice output.',
              ),

              const SizedBox(height: 32),

              // ── Tools section ─────────────────────────────────────────────
              Text(
                'All Tools',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ibmCoolGray,
                    ),
              ).animate().fadeIn(delay: 300.ms, duration: 350.ms),

              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: _tools.length,
                itemBuilder: (context, index) {
                  return FeatureCard(item: _tools[index], index: index);
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: const VoiceFAB(),
    );
  }
}

// ── Mode button widget ────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    required this.semanticsLabel,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.read<VoiceProvider>().speak(semanticsLabel);
            Navigator.pushNamed(context, route);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 250 + index * 60),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon bubble
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.ibmCoolGray,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: color.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 200 + index * 80),
          duration: 400.ms,
        );
  }
}

/// FeatureItem — reused by [FeatureCard] and defined here so [feature_card.dart]
/// can import from a single source.  Kept identical to the previous definition
/// so no dependent code changes.
class FeatureItem {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final String route;
  final String voiceHint;

  const FeatureItem({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.route,
    required this.voiceHint,
  });
}
