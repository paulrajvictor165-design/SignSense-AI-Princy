/// SignSense AI — Deaf & Mute AI Communication Assistant
///
/// Phase E — sign language camera → text + voice.
///
/// Architecture
/// ─────────────
/// Mode 2 is the entry point for Deaf & Mute users.
///
///   Camera stream frames
///       ↓
///   DetectionService (DetectionMode.signLanguage → /api/sign/recognize)
///       ↓
///   Response: sign_label, confidence, description, voice_message, low_confidence
///       ↓
///   UI: large text panel + voice output (for hearing people around the user)
///
/// Design principles
/// ─────────────────
/// 1. LARGE, high-contrast text output — deaf users need to read results.
/// 2. Voice synthesis for *others* in the environment, not the user.
/// 3. Auto-capture mode: continuously reads signs from the stream with
///    a minimum interval to prevent duplicate announcements.
/// 4. Manual capture: user can also tap "Capture" to freeze a frame.
/// 5. Recognized signs build up a "message" string that can be read aloud
///    by the user to communicate with a hearing person.
/// 6. A "Clear" button resets the accumulated message.
/// 7. A "Speak" button speaks the accumulated message for hearing-person output.
///
/// The backend /api/sign/recognize endpoint is wired in Phase D.
/// DetectionMode.signLanguage points to /api/sign/recognize in detection_service.dart.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/voice_provider.dart';
import '../core/network/api_client.dart';
import '../core/errors/app_exception.dart';
import '../utils/app_theme.dart';
import '../utils/app_routes.dart';

class DeafModeScreen extends StatefulWidget {
  const DeafModeScreen({super.key});

  @override
  State<DeafModeScreen> createState() => _DeafModeScreenState();
}

class _DeafModeScreenState extends State<DeafModeScreen>
    with WidgetsBindingObserver {
  // ── Services ──────────────────────────────────────────────────────────────
  final ApiClient _client = ApiClient();

  // ── Sign recognition state ────────────────────────────────────────────────
  String _currentSign = '';
  double _confidence = 0.0;
  bool _lowConfidence = false;
  bool _isCapturing = false;

  // Accumulated message from individual signs
  final List<String> _message = [];
  String get _composedMessage => _message.join(' ');

  // Auto-capture timer — captures a frame every N seconds automatically
  Timer? _autoCaptureTimer;
  static const Duration _autoCaptureInterval = Duration(seconds: 3);
  bool _autoCapture = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    await context.read<CameraProvider>().initializeCameras();
    if (mounted) {
      context.read<VoiceProvider>().speak(
        'Deaf and Mute AI Assistant. '
        'Show a hand sign in front of the camera. '
        'Tap Capture to recognize the sign, or enable Auto Capture.',
      );
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
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    final image = await context.read<CameraProvider>().takePicture();
    if (image == null) {
      setState(() => _isCapturing = false);
      return;
    }

    try {
      final result = await _client.uploadImageFile(
        '/api/sign/recognize',
        image.path,
      );

      final signLabel = result['sign_label'] as String? ?? 'UNKNOWN';
      final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
      final description = result['description'] as String? ?? '';
      final voiceMsg = result['voice_message'] as String? ?? '';
      final lowConf = result['low_confidence'] as bool? ?? false;

      setState(() {
        _currentSign = signLabel == 'NO_HAND' || signLabel == 'UNKNOWN'
            ? signLabel
            : signLabel;
        _confidence = confidence;
        _lowConfidence = lowConf;
        _isCapturing = false;

        // Only append recognized, high-confidence signs to the message
        if (signLabel != 'NO_HAND' &&
            signLabel != 'UNKNOWN' &&
            signLabel != 'ERROR' &&
            !lowConf) {
          _message.add(signLabel);
        }
      });

      // Speak the voice message aloud so hearing people around can understand
      if (voiceMsg.isNotEmpty) {
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
    setState(() => _isCapturing = false);
    context.read<VoiceProvider>().speak(message);
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
      context.read<VoiceProvider>().speak('Auto capture disabled.');
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
            Text('Deaf & Mute AI Assistant'),
          ],
        ),
        actions: [
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
          // SOS shortcut
          Semantics(
            label: 'Emergency SOS',
            child: IconButton(
              icon: const Icon(Icons.sos_outlined, color: AppTheme.ibmRed),
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pushNamed(context, AppRoutes.sos);
              },
              tooltip: 'SOS',
            ),
          ),
        ],
      ),

      body: Column(
        children: [
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
                      // Hand-framing guide overlay
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.ibmPurple.withOpacity(0.8),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'Place hand here',
                              style: TextStyle(
                                color: AppTheme.ibmPurple.withOpacity(0.9),
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
                      // Low-confidence banner
                      if (_lowConfidence && _currentSign.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          left: 12,
                          right: 12,
                          child: Semantics(
                            label: 'Low confidence. Improve lighting or positioning.',
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
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.ibmPurple),
                  ),
          ),

          // ── Detected sign display ─────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppTheme.surfaceDark,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    onPressed: _isCapturing ? null : _captureSign,
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
                    label: Text(_isCapturing ? 'Reading...' : 'Capture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.ibmPurple,
                      minimumSize: const Size(110, 48),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Composed message panel ─────────────────────────────────────
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
                        // Speak button
                        Semantics(
                          label: 'Speak composed message',
                          button: true,
                          child: TextButton.icon(
                            onPressed: _speakMessage,
                            icon: const Icon(Icons.volume_up,
                                color: AppTheme.ibmPurple, size: 16),
                            label: const Text(
                              'Speak',
                              style: TextStyle(
                                  color: AppTheme.ibmPurple, fontSize: 12),
                            ),
                          ),
                        ),
                        // Clear button
                        Semantics(
                          label: 'Clear message',
                          button: true,
                          child: TextButton.icon(
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
                        ),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Semantics(
                      label: _composedMessage.isEmpty
                          ? 'No message yet. Capture signs to build a message.'
                          : 'Composed message: $_composedMessage',
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
