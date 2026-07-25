import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/voice_provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      icon: Icons.visibility_outlined,
      title: 'See the World\nDifferently',
      description:
          'SignSense AI uses advanced computer vision to describe your surroundings in real time.',
      color: AppTheme.ibmBlue,
      voiceText:
          'Welcome. SignSense AI helps you see the world using AI-powered camera intelligence.',
    ),
    OnboardingData(
      icon: Icons.record_voice_over_outlined,
      title: 'Real-Time\nVoice Guidance',
      description:
          'Hear instant audio descriptions: objects, people, traffic signals, text, and currency.',
      color: AppTheme.ibmGreen,
      voiceText:
          'SignSense AI speaks everything it sees. Objects, text, traffic, and people are described aloud.',
    ),
    OnboardingData(
      icon: Icons.navigation_outlined,
      title: 'Smart\nNavigation',
      description:
          'Get step-by-step navigation assistance that warns you of obstacles and guides your path.',
      color: AppTheme.ibmPurple,
      voiceText:
          'Navigate safely with smart turn-by-turn guidance and obstacle detection.',
    ),
    OnboardingData(
      icon: Icons.sos_outlined,
      title: 'Emergency\nSOS',
      description:
          'One tap sends your live location to emergency contacts. Never face a crisis alone.',
      color: AppTheme.ibmRed,
      voiceText:
          'In an emergency, tap SOS to instantly alert your contacts with your location.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentPage();
    });
  }

  void _speakCurrentPage() {
    if (!mounted) return;

    context.read<VoiceProvider>().speak(
          _pages[_currentPage].voiceText,
        );
  }

  void _onPageChanged(int index) {
    if (!mounted) return;

    setState(() {
      _currentPage = index;
    });

    _speakCurrentPage();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    await context.read<AppProvider>().setFirstLaunchComplete();

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.home,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  label: 'Skip onboarding',
                  button: true,
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppTheme.ibmCoolGray,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? _pages[_currentPage].color
                          : AppTheme.ibmCoolGray,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Semantics(
                label: _currentPage == _pages.length - 1
                    ? 'Get Started'
                    : 'Next page',
                button: true,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    minimumSize: const Size(
                      double.infinity,
                      56,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 12,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.color.withOpacity(0.15),
                      border: Border.all(
                        color: data.color,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      data.icon,
                      size: 64,
                      color: data.color,
                    ),
                  )
                      .animate()
                      .fadeIn(
                        duration: 500.ms,
                      )
                      .scale(
                        begin: const Offset(0.8, 0.8),
                      ),

                  const SizedBox(height: 24),

                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: 200.ms,
                        duration: 500.ms,
                      )
                      .slideY(
                        begin: 0.3,
                        end: 0,
                      ),

                  const SizedBox(height: 16),

                  Text(
                    data.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.ibmCoolGray,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: 400.ms,
                        duration: 500.ms,
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String voiceText;

  const OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.voiceText,
  });
}