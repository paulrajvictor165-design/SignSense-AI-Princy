/// SignSense AI — Blind AI Voice Assistant Mode
///
/// Phase C — full-screen voice-first AI loop.
///
/// Architecture
/// ─────────────
/// This screen is the Mode 1 entry point.  It combines:
///   • Live camera stream → object detection via [DetectionService]
///     (same token-bucket throttling as CameraScreen, priority voice logic)
///   • Quick-action row for: OCR, Scene Description, Currency, Navigation
///   • Bottom sheet command panel for each feature (tap or voice command)
///   • Emergency SOS shortcut always visible
///
/// Design principles
/// ─────────────────
/// 1. NO visual clutter — the screen is full-screen camera with a minimal
///    bottom control strip.  Blind users operate entirely by voice.
/// 2. All interactive elements have large tap targets (≥ 56 dp) and
///    exhaustive Semantics labels.
/// 3. Every action is confirmed by voice before and after execution.
/// 4. Object detection runs continuously in the background; voice
///    announcements fire automatically with priority ordering (Module 3).
/// 5. A persistent microphone FAB opens the voice command panel.
///
/// Voice commands understood on this screen:
///   "read text" / "ocr"        → OCR capture
///   "describe"                 → Scene description
///   "currency"                 → Currency detection
///   "navigate" / "navigation"  → Navigation screen
///   "SOS" / "emergency"        → SOS screen
///   "stop" / "pause"           → Pause detection stream
///   "resume" / "start"         → Resume detection stream
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/voice_provider.dart';
import '../services/detection_service.dart';
import '../widgets/detection_overlay.dart';
import '../models/detection_result.dart';
import '../utils/app_theme.dart';
import '../utils/app_routes.dart';

class BlindModeScreen extends StatefulWidget {
  const BlindModeScreen({super.key});

  @override
  State<BlindModeScreen> createState() => _BlindModeScreenState();
}

class _BlindModeScreenState extends State<BlindModeScreen>
    with WidgetsBindingObserver {
  // ── Services ──────────────────────────────────────────────────────────────
  final DetectionService _detectionService = DetectionService();

  // ── Detection state ───────────────────────────────────────────────────────
  List<DetectionResult> _detections = const [];
  bool _streamPaused = false;
  bool _showLowConfidenceBanner = false;

  // Voice debounce — same constants as CameraScreen
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _voiceGapMs = 2500;
  static const int _criticalVoiceGapMs = 1000;

  // FPS debug counter (debug-only)
  int _frameCount = 0;
  int _inferenceCount = 0;
  int _displayedFps = 0;
  int _displayedIps = 0;
  Timer? _fpsTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startFpsTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final camera = context.read<CameraProvider>();
    await camera.initializeCameras();
    if (mounted) {
      context.read<VoiceProvider>().speak(
        'Blind AI Voice Assistant. '
        'Camera is active. '
        'Scanning surroundings and announcing detected objects. '
        'Tap the microphone button for voice commands.',
      );
      _startStream();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = context.read<CameraProvider>();
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      camera.stopImageStream();
    } else if (state == AppLifecycleState.resumed &&
        camera.isInitialized &&
        !_streamPaused) {
      _startStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fpsTimer?.cancel();
    context.read<CameraProvider>().stopImageStream();
    super.dispose();
  }

  // ── Stream management ─────────────────────────────────────────────────────

  void _startStream() {
    if (_streamPaused) return;
    final camera = context.read<CameraProvider>();
    if (!camera.isInitialized) return;
    camera.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) {
    _frameCount++;
    _processFrame(image);
  }

  Future<void> _processFrame(CameraImage image) async {
    final results = await _detectionService.detectFromCameraImage(
      image,
      mode: DetectionMode.objects,
    );
    if (results.isEmpty) return;

    _inferenceCount++;
    if (mounted) {
      final hasCritical = results.any((d) => d.isCritical);
      final topLowConf = results.isNotEmpty && results.first.lowConfidence;
      setState(() {
        _detections = results;
        _showLowConfidenceBanner = topLowConf && !hasCritical;
      });
      _announceDetections(results);
    }
  }

  void _announceDetections(List<DetectionResult> detections) {
    if (detections.isEmpty) return;
    final hasCritical = detections.any((d) => d.isCritical);
    final now = DateTime.now();
    final elapsed = now.difference(_lastSpokenAt).inMilliseconds;
    final gap = hasCritical ? _criticalVoiceGapMs : _voiceGapMs;
    if (elapsed < gap) return;
    _lastSpokenAt = now;

    final message = detections.take(3).map((d) => d.voiceMessage).join('. ');
    if (hasCritical) {
      context.read<VoiceProvider>().speakPriority(message);
    } else {
      context.read<VoiceProvider>().speak(message);
    }
  }

  // ── Voice command handler ─────────────────────────────────────────────────

  void _handleVoiceCommand(String command) {
    final voice = context.read<VoiceProvider>();
    final lower = command.toLowerCase();

    if (lower.contains('read') || lower.contains('ocr') ||
        lower.contains('text')) {
      voice.speak('Opening text reader.');
      Navigator.pushNamed(context, AppRoutes.ocr);
    } else if (lower.contains('describe') || lower.contains('scene')) {
      voice.speak('Opening scene description.');
      Navigator.pushNamed(context, AppRoutes.sceneDescription);
    } else if (lower.contains('currency') || lower.contains('money') ||
        lower.contains('rupee')) {
      voice.speak('Opening currency detection.');
      Navigator.pushNamed(context, AppRoutes.currency);
    } else if (lower.contains('navigate') || lower.contains('navigation') ||
        lower.contains('direction')) {
      voice.speak('Opening navigation.');
      Navigator.pushNamed(context, AppRoutes.navigation);
    } else if (lower.contains('sos') || lower.contains('emergency') ||
        lower.contains('help')) {
      voice.speakPriority('Opening emergency SOS.');
      Navigator.pushNamed(context, AppRoutes.sos);
    } else if (lower.contains('stop') || lower.contains('pause')) {
      _pauseStream();
    } else if (lower.contains('resume') || lower.contains('start')) {
      _resumeStream();
    } else {
      voice.speak(
        'Command not recognized. '
        'Say: read text, describe scene, currency, navigate, SOS, stop, or resume.',
      );
    }
  }

  void _pauseStream() {
    context.read<CameraProvider>().stopImageStream();
    setState(() => _streamPaused = true);
    context.read<VoiceProvider>().speak('Detection paused.');
  }

  void _resumeStream() {
    setState(() => _streamPaused = false);
    _startStream();
    context.read<VoiceProvider>().speak('Detection resumed.');
  }

  // ── Debug FPS ─────────────────────────────────────────────────────────────

  void _startFpsTimer() {
    if (!kDebugMode) return;
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _displayedFps = _frameCount;
          _displayedIps = _inferenceCount;
          _frameCount = 0;
          _inferenceCount = 0;
        });
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    final voice = context.watch<VoiceProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      // Minimal AppBar — just a back button and a mode label
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Row(
          children: [
            Icon(Icons.hearing_outlined, color: AppTheme.ibmBlue, size: 20),
            SizedBox(width: 8),
            Text('Blind AI Voice Assistant'),
          ],
        ),
        actions: [
          // Debug FPS
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Text(
                '${_displayedFps}f/${_displayedIps}i',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          // Flash toggle
          Semantics(
            label: 'Toggle flash',
            child: IconButton(
              icon: Icon(
                cameraProvider.flashMode == FlashMode.off
                    ? Icons.flash_off_outlined
                    : Icons.flash_on_outlined,
                color: Colors.white,
              ),
              onPressed: () => cameraProvider.toggleFlash(),
            ),
          ),
          // Stream pause / resume
          Semantics(
            label: _streamPaused ? 'Resume detection' : 'Pause detection',
            child: IconButton(
              icon: Icon(
                _streamPaused
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
                color: _streamPaused ? AppTheme.ibmGreen : Colors.white,
              ),
              onPressed: _streamPaused ? _resumeStream : _pauseStream,
              tooltip: _streamPaused ? 'Resume' : 'Pause',
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Full-bleed camera + overlays ─────────────────────────────────
          Expanded(
            child: cameraProvider.isInitialized
                ? Stack(
                    children: [
                      // Camera preview
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: cameraProvider
                                .controller!.value.previewSize!.height,
                            height: cameraProvider
                                .controller!.value.previewSize!.width,
                            child: CameraPreview(cameraProvider.controller!),
                          ),
                        ),
                      ),
                      // Bounding-box overlay
                      DetectionOverlay(detections: _detections),
                      // Stream-paused overlay
                      if (_streamPaused)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pause_circle_outline,
                                    color: Colors.white70, size: 64),
                                SizedBox(height: 12),
                                Text(
                                  'Detection paused',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Low-confidence banner
                      if (_showLowConfidenceBanner)
                        Positioned(
                          bottom: 8,
                          left: 12,
                          right: 12,
                          child: Semantics(
                            label:
                                'Low confidence. Move closer for better detection.',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade800.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning_amber_outlined,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Low confidence — move closer or improve lighting',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.ibmBlue),
                  ),
          ),

          // ── Quick-action row ─────────────────────────────────────────────
          Container(
            color: const Color(0xFF1C1C1E),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickAction(
                  icon: Icons.document_scanner_outlined,
                  label: 'Read Text',
                  color: AppTheme.ibmPurple,
                  onTap: () {
                    context
                        .read<VoiceProvider>()
                        .speak('Opening text reader.');
                    Navigator.pushNamed(context, AppRoutes.ocr);
                  },
                ),
                _QuickAction(
                  icon: Icons.landscape_outlined,
                  label: 'Scene',
                  color: AppTheme.ibmTeal,
                  onTap: () {
                    context
                        .read<VoiceProvider>()
                        .speak('Opening scene description.');
                    Navigator.pushNamed(context, AppRoutes.sceneDescription);
                  },
                ),
                _QuickAction(
                  icon: Icons.currency_rupee,
                  label: 'Currency',
                  color: AppTheme.ibmYellow,
                  onTap: () {
                    context
                        .read<VoiceProvider>()
                        .speak('Opening currency detection.');
                    Navigator.pushNamed(context, AppRoutes.currency);
                  },
                ),
                _QuickAction(
                  icon: Icons.navigation_outlined,
                  label: 'Navigate',
                  color: AppTheme.ibmGreen,
                  onTap: () {
                    context.read<VoiceProvider>().speak('Opening navigation.');
                    Navigator.pushNamed(context, AppRoutes.navigation);
                  },
                ),
                _QuickAction(
                  icon: Icons.sos_outlined,
                  label: 'SOS',
                  color: AppTheme.ibmRed,
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    context
                        .read<VoiceProvider>()
                        .speakPriority('Opening emergency SOS.');
                    Navigator.pushNamed(context, AppRoutes.sos);
                  },
                ),
              ],
            ),
          ),

          // ── Detection results strip ──────────────────────────────────────
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60, maxHeight: 120),
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _detections.isEmpty
                ? Center(
                    child: Text(
                      _streamPaused
                          ? 'Detection paused — tap resume to restart'
                          : 'Scanning surroundings…',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _detections.length,
                    itemBuilder: (context, i) {
                      final det = _detections[i];
                      final Color labelColor = det.isCritical
                          ? Colors.red.shade300
                          : det.isHighPriority
                              ? Colors.orange.shade300
                              : Colors.white;
                      return Text(
                        '${det.isCritical ? "⚠ " : ""}${det.label} — '
                        '${(det.confidence * 100).toStringAsFixed(0)}% — '
                        '${det.position}',
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 12,
                          fontWeight: det.isCritical
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
          ),
        ],
      ),

      // ── Voice command FAB ─────────────────────────────────────────────────
      floatingActionButton: Semantics(
        label: voice.isListening
            ? 'Stop voice command'
            : 'Tap for voice command',
        button: true,
        child: FloatingActionButton.extended(
          onPressed: () {
            if (voice.isListening) {
              voice.stopListening();
            } else {
              voice.speak('Listening. Say a command.');
              voice.startListening(onResult: _handleVoiceCommand);
            }
          },
          backgroundColor:
              voice.isListening ? AppTheme.ibmRed : AppTheme.ibmBlue,
          icon: Icon(
            voice.isListening
                ? Icons.mic_outlined
                : Icons.mic_none_outlined,
            color: Colors.white,
          ),
          label: Text(
            voice.isListening ? 'Listening...' : 'Voice Command',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── Quick-action button ────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label button',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
