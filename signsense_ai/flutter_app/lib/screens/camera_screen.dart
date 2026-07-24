import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/voice_provider.dart';
import '../services/detection_service.dart';
import '../utils/app_theme.dart';
import '../widgets/detection_overlay.dart';
import '../models/detection_result.dart';

/// Live-camera screen with continuous object detection.
///
/// Stream design
/// ─────────────
/// The camera stream fires a callback for every frame (≥ 30 FPS at medium
/// resolution).  [DetectionService] applies token-bucket throttling internally,
/// so the UI callback is lightweight: it calls detectFromCameraImage(), gets a
/// result (or an empty list that is silently ignored), and calls setState() only
/// when the result set actually changes.  This keeps the build rate low and the
/// camera preview smooth.
///
/// Voice announcements
/// ────────────────────
/// Detections are spoken at most once every [_voiceGapMs] milliseconds to avoid
/// a torrent of identical speech.  The voice message is debounced independently
/// from the visual overlay refresh.
///
/// Mode selector
/// ─────────────
/// The chip bar shows only the five modes backed by live-stream endpoints.
/// OCR, Currency, and Sign Language are intentionally excluded here — they each
/// have their own dedicated screens.  [DetectionMode] already declares those
/// values for use by other screens without breaking this file.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ── Services ────────────────────────────────────────────────────────────────
  final DetectionService _detectionService = DetectionService();

  // ── State ───────────────────────────────────────────────────────────────────
  List<DetectionResult> _detections = const [];
  DetectionMode _mode = DetectionMode.objects;

  // Module 3: track whether the last response was low-confidence.
  bool _showLowConfidenceBanner = false;

  // Voice debounce
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _voiceGapMs = 2500;

  // Reduced gap for critical-priority warnings — speak sooner when danger present.
  static const int _criticalVoiceGapMs = 1000;

  // Debug FPS counter — only active in debug builds.
  int _frameCount = 0;
  int _inferenceCount = 0;
  int _displayedFps = 0;
  int _displayedIps = 0; // inferences per second
  Timer? _fpsTimer;

  // Modes shown in the chip selector — only the five that use
  // /api/detect/* endpoints. The others have dedicated screens.
  static const List<DetectionMode> _streamModes = [
    DetectionMode.objects,
    DetectionMode.traffic,
    DetectionMode.vehicles,
    DetectionMode.faces,
    DetectionMode.colors,
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startFpsTimer();
    // Defer camera initialisation until the first frame is built so that
    // context.read<> is safe to call.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final cameraProvider = context.read<CameraProvider>();
    await cameraProvider.initializeCameras();
    if (mounted) {
      context.read<VoiceProvider>().speak(
        'Camera opened. Detecting ${_mode.label}. '
        'Point camera at surroundings.',
      );
      _startStream();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraProvider = context.read<CameraProvider>();
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      cameraProvider.stopImageStream();
    } else if (state == AppLifecycleState.resumed &&
        cameraProvider.isInitialized) {
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

  // ── Stream management ────────────────────────────────────────────────────────

  void _startStream() {
    final cameraProvider = context.read<CameraProvider>();
    if (!cameraProvider.isInitialized) return;

    cameraProvider.startImageStream(_onFrame);
  }

  /// Called by the camera plugin for every frame.
  ///
  /// This function must return quickly — any heavy work must be async.
  /// [DetectionService.detectFromCameraImage] returns immediately when the
  /// token bucket is full, so we only launch async work when a new inference
  /// window opens.
  void _onFrame(CameraImage image) {
    _frameCount++;

    // Fire-and-forget — we do not await here so the stream callback returns
    // immediately and the camera HAL can deliver the next frame.
    _processFrame(image);
  }

  Future<void> _processFrame(CameraImage image) async {
    final results = await _detectionService.detectFromCameraImage(
      image,
      mode: _mode,
    );

    // Empty list means "frame was throttled" — keep the last result set
    // visible rather than clearing the overlay.
    if (results.isEmpty) return;

    _inferenceCount++;

    if (mounted) {
      // Module 3: show low-confidence banner when top detection is uncertain.
      final hasCritical = results.any((d) => d.isCritical);
      final topLowConf  = results.isNotEmpty && results.first.lowConfidence;
      setState(() {
        _detections = results;
        _showLowConfidenceBanner = topLowConf && !hasCritical;
      });
      _announceDetections(results);
    }
  }

  // ── Voice announcements ──────────────────────────────────────────────────────

  void _announceDetections(List<DetectionResult> detections) {
    if (detections.isEmpty) return;

    // Module 3: critical objects bypass the normal voice gap — they are
    // spoken immediately (subject only to the shorter critical gap).
    final hasCritical = detections.any((d) => d.isCritical);
    final now = DateTime.now();
    final elapsed = now.difference(_lastSpokenAt).inMilliseconds;
    final requiredGap = hasCritical ? _criticalVoiceGapMs : _voiceGapMs;
    if (elapsed < requiredGap) return;
    _lastSpokenAt = now;

    // Backend already returns detections priority-sorted.
    // voiceMessage getter prepends "Warning!" / "Caution!" for critical/high.
    final message = detections.take(3).map((d) => d.voiceMessage).join(' ');

    if (hasCritical) {
      // Interrupt any current speech for critical safety warnings.
      context.read<VoiceProvider>().speakPriority(message);
    } else {
      context.read<VoiceProvider>().speak(message);
    }
  }

  // ── Mode switching ───────────────────────────────────────────────────────────

  Future<void> _switchMode(DetectionMode mode) async {
    if (_mode == mode) return;
    final cameraProvider = context.read<CameraProvider>();
    await cameraProvider.stopImageStream();
    setState(() {
      _mode = mode;
      _detections = const [];
    });
    context.read<VoiceProvider>().speak('Switched to ${mode.label} mode.');
    _startStream();
  }

  // ── Debug FPS counter ────────────────────────────────────────────────────────

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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${_mode.label} Detection'),
        actions: [
          // Debug FPS counter — stripped in release builds.
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
              tooltip: 'Toggle Flash',
            ),
          ),
          Semantics(
            label: 'Switch camera',
            child: IconButton(
              icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
              onPressed: () async {
                await cameraProvider.switchCamera();
                _startStream();
              },
              tooltip: 'Switch Camera',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Camera preview + detection overlay ──────────────────────────
          Expanded(
            child: cameraProvider.isInitialized
                ? Stack(
                    children: [
                      // Full-bleed camera preview
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
                      // Bounding-box overlay — repaints only when _detections changes
                      DetectionOverlay(detections: _detections),
                      // Module 3: Low-confidence banner — prompts user to rescan.
                      if (_showLowConfidenceBanner)
                        Positioned(
                          bottom: 8,
                          left: 12,
                          right: 12,
                          child: Semantics(
                            label: 'Low confidence. Move closer for better detection.',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
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
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Processing indicator (taken-picture path only)
                      if (cameraProvider.isProcessing)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.ibmBlue,
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.ibmBlue),
                  ),
          ),

          // ── Mode selector chip bar ──────────────────────────────────────
          Container(
            color: Colors.black,
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _streamModes.map((mode) {
                  final isSelected = _mode == mode;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Semantics(
                      label: 'Switch to ${mode.label} mode',
                      selected: isSelected,
                      button: true,
                      child: GestureDetector(
                        onTap: () => _switchMode(mode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.ibmBlue
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.ibmBlue
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            mode.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Detection results panel ─────────────────────────────────────
          Container(
            width: double.infinity,
            constraints:
                const BoxConstraints(minHeight: 80, maxHeight: 140),
            color: const Color(0xFF1C1C1E),
            padding: const EdgeInsets.all(12),
            child: _detections.isEmpty
                ? const Center(
                    child: Text(
                      'Scanning surroundings…',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _detections.length,
                    itemBuilder: (context, index) {
                      final det = _detections[index];
                      // Module 3: colour-code by priority tier.
                      final Color labelColor = det.isCritical
                          ? Colors.red.shade300
                          : det.isHighPriority
                              ? Colors.orange.shade300
                              : Colors.white;
                      return Text(
                        '${det.isCritical ? "⚠ " : ""}'
                        '${det.label} — '
                        '${(det.confidence * 100).toStringAsFixed(0)}% — '
                        '${det.position}',
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 13,
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
    );
  }
}
