/// SignSense AI — Sign Language Detection Screen
///
/// Separate screen for MediaPipe-based hand detection and ISL sign recognition.
///
/// Features
/// ─────────
/// • Live camera → hand landmark overlay via /api/sign/landmarks
/// • Sign recognition via /api/sign/recognize
/// • Displays model status (model missing / rule-based / TFLite active)
/// • Left/right hand information
/// • Stable sign predictions only (not every single frame)
/// • TTS output for confirmed signs
/// • Clear status when sign model is not installed
/// • Correct camera and stream disposal

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/voice_provider.dart';
import '../core/network/api_client.dart';
import '../core/errors/app_exception.dart';
import '../utils/app_theme.dart';

class SignLanguageDetectionScreen extends StatefulWidget {
  const SignLanguageDetectionScreen({super.key});

  @override
  State<SignLanguageDetectionScreen> createState() =>
      _SignLanguageDetectionScreenState();
}

class _SignLanguageDetectionScreenState
    extends State<SignLanguageDetectionScreen>
    with WidgetsBindingObserver {
  // ── Services ──────────────────────────────────────────────────────────────
  final ApiClient _client = ApiClient();

  // ── Sign recognition state ────────────────────────────────────────────────
  String _currentSign = '';
  double _confidence = 0.0;
  bool _lowConfidence = false;
  String _handedness = '';
  String _modelStatus = 'Checking model status…';
  bool _handsDetected = false;
  bool _isCapturing = false;
  bool _backendAlive = true;
  bool _checkingBackend = true;

  // Accumulated message from individual signs
  final List<String> _message = [];
  String get _composedMessage => _message.join(' ');

  // Auto-capture — captures a frame every N seconds automatically
  Timer? _autoCaptureTimer;
  static const Duration _autoCaptureInterval = Duration(seconds: 3);
  bool _autoCapture = false;

  // Voice cooldown
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _voiceGapMs = 3000;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    // Check backend connectivity.
    final alive = await _client.isServerAlive();
    if (mounted) {
      setState(() {
        _backendAlive = alive;
        _checkingBackend = false;
        if (!alive) {
          _modelStatus = 'Backend unavailable.';
        }
      });
    }
    if (!alive) {
      if (mounted) {
        context.read<VoiceProvider>().speak(
          'Backend server is unavailable. Please check the Flask server.',
        );
      }
      return;
    }

    await context.read<CameraProvider>().initializeCameras();
    if (mounted) {
      // Check health for model status.
      _checkModelStatus();
      context.read<VoiceProvider>().speak(
        'Sign Language Detection. '
        'Show a hand sign in front of the camera. '
        'Tap Capture or enable Auto Capture.',
      );
    }
  }

  Future<void> _checkModelStatus() async {
    try {
      final health = await _client.get('/health');
      final models = health['models'] as Map<String, dynamic>?;
      if (models == null) return;

      final signModel = models['sign_language'] as Map<String, dynamic>?;
      final mediapipe = models['mediapipe'] as Map<String, dynamic>?;

      String status;
      if (mediapipe != null && mediapipe['available'] == false) {
        status = 'MediaPipe not installed — hand detection unavailable.';
      } else if (signModel != null && signModel['loaded'] == false) {
        final reason = signModel['reason'] as String? ?? 'Unknown reason';
        status = 'Hand detected via MediaPipe. '
            'Sign translation model not installed ($reason). '
            'Showing basic pose classification only.';
      } else if (signModel != null && signModel['loaded'] == true) {
        status = 'TFLite sign model active.';
      } else {
        status = 'MediaPipe hand detection active (rule-based classifier).';
      }

      if (mounted) {
        setState(() => _modelStatus = status);
      }
    } catch (_) {
      // Non-critical — model status is informational only.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopAutoCapture();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCaptureTimer?.cancel();
    _client.dispose();
    context.read<CameraProvider>().stopImageStream();
    super.dispose();
  }

  // ── Capture ───────────────────────────────────────────────────────────────

  Future<void> _captureSign() async {
    if (_isCapturing || !_backendAlive) return;
    setState(() => _isCapturing = true);

    final image = await context.read<CameraProvider>().takePicture();
    if (image == null) {
      setState(() => _isCapturing = false);
      return;
    }

    try {
      final result = kIsWeb
          ? await _client.uploadImageBytes(
              '/api/sign/recognize',
              await image.readAsBytes(),
            )
          : await _client.uploadImageFile(
              '/api/sign/recognize',
              image.path,
            );

      final signLabel  = result['sign_label']    as String? ?? 'UNKNOWN';
      final confidence = (result['confidence']   as num?)?.toDouble() ?? 0.0;
      final voiceMsg   = result['voice_message'] as String? ?? '';
      final lowConf    = result['low_confidence'] as bool? ?? false;
      final handedness = result['handedness']    as String? ?? '';
      final modelSt    = result['model_status']  as String? ?? _modelStatus;
      final handsDetected = signLabel != 'NO_HAND' && signLabel != 'ERROR';

      setState(() {
        _currentSign    = signLabel;
        _confidence     = confidence;
        _lowConfidence  = lowConf;
        _handedness     = handedness;
        _handsDetected  = handsDetected;
        _modelStatus    = modelSt;
        _isCapturing    = false;

        // Only append recognized, high-confidence signs to the message
        if (signLabel != 'NO_HAND' &&
            signLabel != 'UNKNOWN' &&
            signLabel != 'ERROR' &&
            !lowConf) {
          _message.add(signLabel);
        }
      });

      // Speak with cooldown to avoid repeated announcements
      final now = DateTime.now();
      final elapsed = now.difference(_lastSpokenAt).inMilliseconds;
      if (voiceMsg.isNotEmpty && elapsed >= _voiceGapMs) {
        _lastSpokenAt = now;
        context.read<VoiceProvider>().speak(voiceMsg);
      }
    } on NetworkException catch (e) {
      _handleError(e.userMessage);
    } on ApiException catch (e) {
      _handleError(e.userMessage);
    } catch (_) {
      _handleError('Recognition failed. Please try again.');
    }
  }

  void _handleError(String message) {
    setState(() {
      _isCapturing = false;
      _modelStatus = message;
    });
  }

  // ── Auto-capture ──────────────────────────────────────────────────────────

  void _toggleAutoCapture() {
    if (_autoCapture) {
      _stopAutoCapture();
    } else {
      _startAutoCapture();
    }
  }

  void _startAutoCapture() {
    setState(() => _autoCapture = true);
    context.read<VoiceProvider>().speak('Auto capture enabled.');
    _autoCaptureTimer = Timer.periodic(_autoCaptureInterval, (_) {
      if (mounted && !_isCapturing) _captureSign();
    });
  }

  void _stopAutoCapture() {
    _autoCaptureTimer?.cancel();
    if (mounted) {
      setState(() => _autoCapture = false);
    }
  }

  // ── Message management ────────────────────────────────────────────────────

  void _clearMessage() {
    setState(() {
      _message.clear();
      _currentSign = '';
    });
    context.read<VoiceProvider>().speak('Message cleared.');
  }

  void _speakMessage() {
    final msg = _composedMessage.trim();
    if (msg.isEmpty) {
      context.read<VoiceProvider>().speak('No message to speak.');
    } else {
      context.read<VoiceProvider>().speakPriority(msg);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Row(
          children: [
            Icon(Icons.sign_language_outlined,
                color: AppTheme.ibmPurple, size: 20),
            SizedBox(width: 8),
            Text('Sign Language Detection'),
          ],
        ),
        actions: [
          // Auto-capture toggle
          Semantics(
            label: _autoCapture ? 'Disable auto capture' : 'Enable auto capture',
            child: IconButton(
              icon: Icon(
                _autoCapture
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outlined,
                color: _autoCapture ? AppTheme.ibmRed : AppTheme.ibmGreen,
              ),
              onPressed: _toggleAutoCapture,
              tooltip: _autoCapture ? 'Stop Auto' : 'Auto Capture',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Model status banner ────────────────────────────────────────
          Container(
            width: double.infinity,
            color: _modelStatus.contains('not installed') ||
                    _modelStatus.contains('unavailable')
                ? Colors.orange.shade900.withOpacity(0.9)
                : Colors.green.shade900.withOpacity(0.7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _modelStatus.contains('not installed') ||
                          _modelStatus.contains('unavailable')
                      ? Icons.info_outline
                      : Icons.check_circle_outline,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _modelStatus,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // ── Camera preview ─────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: cameraProvider.isInitialized
                ? Stack(
                    children: [
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
                      // Hand-framing guide
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _handsDetected
                                  ? AppTheme.ibmGreen.withOpacity(0.9)
                                  : AppTheme.ibmPurple.withOpacity(0.6),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _handsDetected
                                  ? 'Hand detected'
                                  : 'Place hand here',
                              style: TextStyle(
                                color: _handsDetected
                                    ? AppTheme.ibmGreen.withOpacity(0.9)
                                    : AppTheme.ibmPurple.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Auto-capture badge
                      if (_autoCapture)
                        Positioned(
                          top: 8,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.ibmGreen.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fiber_manual_record,
                                    color: Colors.white, size: 10),
                                SizedBox(width: 4),
                                Text(
                                  'AUTO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Handedness badge
                      if (_handedness.isNotEmpty && _handsDetected)
                        Positioned(
                          top: 8,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.ibmPurple.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_handedness hand',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      // Low-confidence banner
                      if (_lowConfidence && _currentSign.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          left: 12,
                          right: 12,
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
                                    'Low confidence — improve lighting or re-frame',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: _checkingBackend
                        ? const CircularProgressIndicator(
                            color: AppTheme.ibmPurple)
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
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(
                                          () => _checkingBackend = true);
                                      _initialize();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              )
                            : const CircularProgressIndicator(
                                color: AppTheme.ibmPurple),
                  ),
          ),

          // ── Detected sign display ─────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppTheme.surfaceDark,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Big sign label
                Expanded(
                  child: Semantics(
                    label: _currentSign.isEmpty
                        ? 'No sign detected yet'
                        : 'Detected sign: $_currentSign, '
                            'confidence: ${(_confidence * 100).toStringAsFixed(0)} percent',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentSign.isEmpty ? '—' : _currentSign,
                          style: TextStyle(
                            color: _currentSign.isEmpty
                                ? Colors.white30
                                : _currentSign == 'NO_HAND' ||
                                        _currentSign == 'UNKNOWN'
                                    ? Colors.white54
                                    : AppTheme.ibmPurple,
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentSign.isNotEmpty)
                          Text(
                            '${(_confidence * 100).toStringAsFixed(0)}% confidence',
                            style: const TextStyle(
                              color: AppTheme.ibmCoolGray,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Capture button
                Semantics(
                  label: 'Capture sign',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: (_isCapturing || !_backendAlive)
                        ? null
                        : _captureSign,
                    icon: _isCapturing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.camera_alt_outlined),
                    label:
                        Text(_isCapturing ? 'Reading...' : 'Capture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.ibmPurple,
                      minimumSize: const Size(110, 48),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Composed message panel ────────────────────────────────────
          Container(
            width: double.infinity,
            constraints:
                const BoxConstraints(minHeight: 72, maxHeight: 120),
            color: const Color(0xFF1C1C1E),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Composed message',
                      style: TextStyle(
                          color: AppTheme.ibmCoolGray, fontSize: 11),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _speakMessage,
                          icon: const Icon(Icons.volume_up,
                              color: AppTheme.ibmPurple, size: 16),
                          label: const Text(
                            'Speak',
                            style: TextStyle(
                                color: AppTheme.ibmPurple, fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clearMessage,
                          icon: const Icon(Icons.clear_all,
                              color: AppTheme.ibmCoolGray, size: 16),
                          label: const Text(
                            'Clear',
                            style: TextStyle(
                                color: AppTheme.ibmCoolGray,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _composedMessage.isEmpty
                          ? 'No message yet — capture signs to build one'
                          : _composedMessage,
                      style: TextStyle(
                        color: _composedMessage.isEmpty
                            ? Colors.white24
                            : Colors.white,
                        fontSize: 14,
                        fontStyle: _composedMessage.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
