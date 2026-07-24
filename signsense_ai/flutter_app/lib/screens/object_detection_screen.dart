/// SignSense AI — Object Detection Screen
///
/// Separate full-screen object detection using YOLOv8 via the backend.
/// This is distinct from CameraScreen (which is a multi-mode camera).
///
/// Features
/// ─────────
/// • Live camera stream → POST /api/detect/objects
/// • Correctly scaled bounding boxes over the camera preview
/// • Priority-coloured detection labels
/// • Voice announcements with cooldown (no repeated speech)
/// • Backend offline / model missing / no detection states
/// • Frame throttling via DetectionService token bucket
/// • Camera and stream disposal on screen exit

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/voice_provider.dart';
import '../services/detection_service.dart';
import '../widgets/detection_overlay.dart';
import '../models/detection_result.dart';
import '../utils/app_theme.dart';
import '../core/network/api_client.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen>
    with WidgetsBindingObserver {
  // ── Services ────────────────────────────────────────────────────────────────
  final DetectionService _detectionService = DetectionService();
  final ApiClient _client = ApiClient();

  // ── State ───────────────────────────────────────────────────────────────────
  List<DetectionResult> _detections = const [];
  bool _showLowConfidenceBanner = false;
  bool _backendAlive = true;
  bool _checkingBackend = true;
  String _statusMessage = 'Scanning surroundings…';

  // Voice debounce
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _voiceGapMs = 2500;
  static const int _criticalVoiceGapMs = 1000;

  // Debug FPS counter
  int _frameCount = 0;
  int _inferenceCount = 0;
  int _displayedFps = 0;
  int _displayedIps = 0;
  Timer? _fpsTimer;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startFpsTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    // 1. Check backend is reachable.
    final alive = await _client.isServerAlive();
    if (mounted) {
      setState(() {
        _backendAlive = alive;
        _checkingBackend = false;
        if (!alive) {
          _statusMessage = 'Backend unavailable. Check Wi-Fi connection.';
        }
      });
      if (!alive) {
        context.read<VoiceProvider>().speak(
          'Backend server is unavailable. '
          'Please ensure Flask is running and connected to the same network.',
        );
        return;
      }
    }

    // 2. Initialize camera.
    final cameraProvider = context.read<CameraProvider>();
    await cameraProvider.initializeCameras();
    if (mounted) {
      context.read<VoiceProvider>().speak(
        'Object Detection. Camera is active. Scanning for objects.',
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
        cameraProvider.isInitialized &&
        _backendAlive) {
      _startStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fpsTimer?.cancel();
    _client.dispose();
    // Stop camera stream before disposing.
    context.read<CameraProvider>().stopImageStream();
    super.dispose();
  }

  // ── Stream management ────────────────────────────────────────────────────────

  void _startStream() {
    final cameraProvider = context.read<CameraProvider>();
    if (!cameraProvider.isInitialized) return;
    cameraProvider.startImageStream(_onFrame);
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
      final topLowConf  = results.isNotEmpty && results.first.lowConfidence;
      setState(() {
        _detections = results;
        _showLowConfidenceBanner = topLowConf && !hasCritical;
        _statusMessage = results.isEmpty
            ? 'No objects detected.'
            : '${results.length} object${results.length == 1 ? '' : 's'} detected';
      });
      _announceDetections(results);
    }
  }

  // ── Voice announcements ──────────────────────────────────────────────────────

  void _announceDetections(List<DetectionResult> detections) {
    if (detections.isEmpty) return;

    final hasCritical = detections.any((d) => d.isCritical);
    final now = DateTime.now();
    final elapsed = now.difference(_lastSpokenAt).inMilliseconds;
    final requiredGap = hasCritical ? _criticalVoiceGapMs : _voiceGapMs;
    if (elapsed < requiredGap) return;
    _lastSpokenAt = now;

    // Build message from top 3 priority detections.
    final message = detections.take(3).map((d) => d.voiceMessage).join(' ');

    if (hasCritical) {
      context.read<VoiceProvider>().speakPriority(message);
    } else {
      context.read<VoiceProvider>().speak(message);
    }
  }

  // ── Debug FPS ────────────────────────────────────────────────────────────────

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
        title: const Row(
          children: [
            Icon(Icons.search_outlined, color: AppTheme.ibmBlue, size: 20),
            SizedBox(width: 8),
            Text('Object Detection'),
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
                cameraProvider.isInitialized &&
                        cameraProvider.flashMode == FlashMode.torch
                    ? Icons.flash_on_outlined
                    : Icons.flash_off_outlined,
                color: Colors.white,
              ),
              onPressed: cameraProvider.isInitialized
                  ? () => cameraProvider.toggleFlash()
                  : null,
              tooltip: 'Toggle Flash',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status banner ─────────────────────────────────────────────────
          if (_checkingBackend)
            Container(
              width: double.infinity,
              color: Colors.blueGrey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Connecting to backend…',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (!_checkingBackend && !_backendAlive)
            Container(
              width: double.infinity,
              color: AppTheme.ibmRed.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_outlined,
                      color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Backend unavailable — check Flask server and Wi-Fi',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // ── Camera preview + overlay ──────────────────────────────────────
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
                      // Bounding-box overlay (normalized coords 0.0–1.0)
                      DetectionOverlay(detections: _detections),
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
                : Center(
                    child: _checkingBackend
                        ? const SizedBox.shrink()
                        : !_backendAlive
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.cloud_off_outlined,
                                      color: Colors.white38, size: 64),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Backend Unavailable',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 18),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Start the Flask server and check your\n'
                                    'Wi-Fi or hotspot connection.',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() => _checkingBackend = true);
                                      _initialize();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              )
                            : const CircularProgressIndicator(
                                color: AppTheme.ibmBlue),
                  ),
          ),

          // ── Detection results panel ───────────────────────────────────────
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80, maxHeight: 140),
            color: const Color(0xFF1C1C1E),
            padding: const EdgeInsets.all(12),
            child: _detections.isEmpty
                ? Center(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _detections.length,
                    itemBuilder: (context, index) {
                      final det = _detections[index];
                      final Color labelColor = det.isCritical
                          ? Colors.red.shade300
                          : det.isHighPriority
                              ? Colors.orange.shade300
                              : Colors.white;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            if (det.isCritical)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.warning_amber_outlined,
                                    color: Colors.red, size: 14),
                              ),
                            Expanded(
                              child: Text(
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
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
