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

/// Live camera screen.
///
/// Android / iOS:
/// - Camera preview
/// - Continuous CameraImage streaming
/// - Real-time detection
/// - Flash support where available
///
/// Web:
/// - Laptop/browser camera preview
/// - No CameraImage stream
/// - Flash disabled
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final DetectionService _detectionService = DetectionService();

  CameraProvider? _cameraProvider;
  VoiceProvider? _voiceProvider;

  List<DetectionResult> _detections = const [];
  DetectionMode _mode = DetectionMode.objects;

  bool _showLowConfidenceBanner = false;
  bool _isStartingCamera = false;

  DateTime _lastSpokenAt =
      DateTime.fromMillisecondsSinceEpoch(0);

  static const int _voiceGapMs = 2500;
  static const int _criticalVoiceGapMs = 1000;

  int _frameCount = 0;
  int _inferenceCount = 0;
  int _displayedFps = 0;
  int _displayedIps = 0;

  Timer? _fpsTimer;

  static const List<DetectionMode> _streamModes = [
    DetectionMode.objects,
    DetectionMode.traffic,
    DetectionMode.vehicles,
    DetectionMode.faces,
    DetectionMode.colors,
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _startFpsTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Save provider references while context is active.
    // These references can safely be used in dispose().
    _cameraProvider ??=
        Provider.of<CameraProvider>(context, listen: false);

    _voiceProvider ??=
        Provider.of<VoiceProvider>(context, listen: false);
  }

  Future<void> _initialize() async {
    if (_isStartingCamera) return;

    final cameraProvider = _cameraProvider;

    if (cameraProvider == null) return;

    _isStartingCamera = true;

    try {
      await cameraProvider.initializeCameras();

      if (!mounted) return;

      if (!cameraProvider.isInitialized) {
        debugPrint('Camera could not be initialized.');
        return;
      }

      _voiceProvider?.speak(
        'Camera opened. Detecting ${_mode.label}. '
        'Point camera at surroundings.',
      );

      // Browser camera_web does not provide CameraImage streaming.
      // Therefore stream detection is started only on mobile.
      if (!kIsWeb) {
        await _startStream();
      }
    } catch (e) {
      debugPrint('Camera screen initialization error: $e');
    } finally {
      _isStartingCamera = false;
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final cameraProvider = _cameraProvider;

    if (cameraProvider == null) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!kIsWeb) {
        cameraProvider.stopImageStream();
      }

      return;
    }

    if (state == AppLifecycleState.resumed &&
        cameraProvider.isInitialized) {
      if (!kIsWeb) {
        _startStream();
      }
    }
  }

  Future<void> _startStream() async {
    if (kIsWeb) return;

    final cameraProvider = _cameraProvider;

    if (cameraProvider == null ||
        !cameraProvider.isInitialized ||
        cameraProvider.isStreaming) {
      return;
    }

    try {
      await cameraProvider.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('Unable to start camera stream: $e');
    }
  }

  void _onFrame(CameraImage image) {
    if (!mounted) return;

    _frameCount++;

    // Do not await here. DetectionService handles throttling.
    _processFrame(image);
  }

  Future<void> _processFrame(CameraImage image) async {
    if (!mounted || kIsWeb) return;

    try {
      final results =
          await _detectionService.detectFromCameraImage(
        image,
        mode: _mode,
      );

      if (!mounted || results.isEmpty) return;

      _inferenceCount++;

      final hasCritical =
          results.any((detection) => detection.isCritical);

      final topLowConfidence =
          results.isNotEmpty &&
          results.first.lowConfidence;

      setState(() {
        _detections = results;

        _showLowConfidenceBanner =
            topLowConfidence && !hasCritical;
      });

      _announceDetections(results);
    } catch (e) {
      debugPrint('Frame processing error: $e');
    }
  }

  void _announceDetections(
    List<DetectionResult> detections,
  ) {
    if (!mounted || detections.isEmpty) return;

    final hasCritical =
        detections.any((detection) => detection.isCritical);

    final now = DateTime.now();

    final elapsed =
        now.difference(_lastSpokenAt).inMilliseconds;

    final requiredGap = hasCritical
        ? _criticalVoiceGapMs
        : _voiceGapMs;

    if (elapsed < requiredGap) return;

    _lastSpokenAt = now;

    final message = detections
        .take(3)
        .map((detection) => detection.voiceMessage)
        .join(' ');

    if (hasCritical) {
      _voiceProvider?.speakPriority(message);
    } else {
      _voiceProvider?.speak(message);
    }
  }

  Future<void> _switchMode(
    DetectionMode mode,
  ) async {
    if (_mode == mode) return;

    final cameraProvider = _cameraProvider;

    if (cameraProvider == null) return;

    if (!kIsWeb) {
      await cameraProvider.stopImageStream();
    }

    if (!mounted) return;

    setState(() {
      _mode = mode;
      _detections = const [];
      _showLowConfidenceBanner = false;
    });

    _voiceProvider?.speak(
      'Switched to ${mode.label} mode.',
    );

    if (!kIsWeb) {
      await _startStream();
    }
  }

  Future<void> _switchCamera() async {
    final cameraProvider = _cameraProvider;

    if (cameraProvider == null) return;

    if (!kIsWeb) {
      await cameraProvider.stopImageStream();
    }

    await cameraProvider.switchCamera();

    if (!mounted) return;

    if (!kIsWeb) {
      await _startStream();
    }
  }

  void _startFpsTimer() {
    if (!kDebugMode) return;

    _fpsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          _displayedFps = _frameCount;
          _displayedIps = _inferenceCount;

          _frameCount = 0;
          _inferenceCount = 0;
        });
      },
    );
  }

  Widget _buildCameraPreview(
    CameraProvider cameraProvider,
  ) {
    final controller = cameraProvider.controller;

    if (!cameraProvider.isInitialized ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.ibmBlue,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewAspectRatio =
            controller.value.aspectRatio;

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: previewAspectRatio,
                child: CameraPreview(controller),
              ),
            ),

            // Bounding boxes.
            Positioned.fill(
              child: IgnorePointer(
                child: DetectionOverlay(
                  detections: _detections,
                ),
              ),
            ),

            if (kIsWeb)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Web camera preview active. '
                      'Continuous AI frame detection is available '
                      'on the Android app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

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
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800
                          .withOpacity(0.85),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Low confidence — move closer '
                            'or improve lighting',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (cameraProvider.isProcessing)
              const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.ibmBlue,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildModeSelector() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _streamModes.map((mode) {
            final isSelected = _mode == mode;

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                label: 'Switch to ${mode.label} mode',
                selected: isSelected,
                button: true,
                child: GestureDetector(
                  onTap: () => _switchMode(mode),
                  child: AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.ibmBlue
                          : Colors.white12,
                      borderRadius:
                          BorderRadius.circular(20),
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
    );
  }

  Widget _buildDetectionResults() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 80,
        maxHeight: 140,
      ),
      color: const Color(0xFF1C1C1E),
      padding: const EdgeInsets.all(12),
      child: _detections.isEmpty
          ? Center(
              child: Text(
                kIsWeb
                    ? 'Camera ready — web preview mode'
                    : 'Scanning surroundings…',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _detections.length,
              itemBuilder: (context, index) {
                final detection =
                    _detections[index];

                final Color labelColor =
                    detection.isCritical
                        ? Colors.red.shade300
                        : detection.isHighPriority
                            ? Colors.orange.shade300
                            : Colors.white;

                return Text(
                  '${detection.isCritical ? "⚠ " : ""}'
                  '${detection.label} — '
                  '${(detection.confidence * 100).toStringAsFixed(0)}% — '
                  '${detection.position}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 13,
                    fontWeight: detection.isCritical
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider =
        context.watch<CameraProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '${_mode.label} Detection',
        ),
        actions: [
          if (kDebugMode && !kIsWeb)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 14,
              ),
              child: Text(
                '${_displayedFps}f/${_displayedIps}i',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),

          // Flash is disabled on web.
          if (!kIsWeb)
            Semantics(
              label: 'Toggle flash',
              child: IconButton(
                icon: Icon(
                  cameraProvider.flashMode ==
                          FlashMode.off
                      ? Icons.flash_off_outlined
                      : Icons.flash_on_outlined,
                  color: Colors.white,
                ),
                onPressed:
                    cameraProvider.isInitialized
                        ? cameraProvider.toggleFlash
                        : null,
                tooltip: 'Toggle Flash',
              ),
            ),

          Semantics(
            label: 'Switch camera',
            child: IconButton(
              icon: const Icon(
                Icons.cameraswitch_outlined,
                color: Colors.white,
              ),
              onPressed:
                  cameraProvider.cameras.length > 1
                      ? _switchCamera
                      : null,
              tooltip: 'Switch Camera',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildCameraPreview(
              cameraProvider,
            ),
          ),
          _buildModeSelector(),
          _buildDetectionResults(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _fpsTimer?.cancel();
    _fpsTimer = null;

    // Never use context.read() inside dispose.
    // Use the provider reference saved earlier.
    if (!kIsWeb) {
      _cameraProvider?.stopImageStream();
    }

    super.dispose();
  }
}