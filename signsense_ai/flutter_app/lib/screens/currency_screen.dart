/// SignSense AI — Currency Screen
///
/// Phase A: Migrated from [ApiService] → [ApiClient].
///          Removed the [_currencyVoice] lookup table (AI business logic
///          in the UI layer).  The backend's [currency_service.py] already
///          returns a `voice_message` field — we use that directly.
///
/// BEFORE issues:
///   1. Used deprecated ApiService with its own conflicting ApiException.
///   2. Had a hard-coded Map<String,String> _currencyVoice in the UI class
///      duplicating denomination-to-speech logic already on the backend.
///   3. No typed exception handling.
///
/// AFTER:
///   1. ApiClient.uploadImageFile → /api/currency/detect.
///   2. Backend voice_message field is spoken directly (falls back to
///      "Currency: ₹<denomination>" if the field is empty).
///   3. NetworkException / ApiException caught and spoken to the user.
///
/// UI layout and accessibility semantics are unchanged.

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/voice_provider.dart';
import '../core/network/api_client.dart';
import '../core/errors/app_exception.dart';
import '../utils/app_theme.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final ApiClient _client = ApiClient();
  String _detectedCurrency = '';
  String _denomination = '';
  String _voiceMessage = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().initializeCameras();
      context.read<VoiceProvider>().speak(
        'Currency Detection mode. '
        'Place the note flat under camera and tap Detect.',
      );
    });
  }

  Future<void> _detectCurrency() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _detectedCurrency = '';
      _denomination = '';
      _voiceMessage = '';
    });

    context.read<VoiceProvider>().speak('Scanning currency...');

    final image = await context.read<CameraProvider>().takePicture();
    if (image == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final result = await _client.uploadImageFile(
        '/api/currency/detect',
        image.path,
      );

      final denomination = result['denomination']?.toString() ?? '';
      // voice_message is already built by currency_service.py
      final backendVoice = result['voice_message'] as String? ?? '';
      final voice = backendVoice.isNotEmpty
          ? backendVoice
          : (denomination.isNotEmpty
              ? 'Currency: ₹$denomination'
              : 'Could not identify the currency. Please try again.');

      setState(() {
        _denomination = denomination;
        _detectedCurrency =
            denomination.isNotEmpty ? '₹$denomination' : 'Not recognized';
        _voiceMessage = voice;
        _isProcessing = false;
      });

      context.read<VoiceProvider>().speakPriority(voice);
    } on NetworkException catch (e) {
      _handleError(e.userMessage);
    } on ApiException catch (e) {
      _handleError(e.userMessage);
    } catch (_) {
      _handleError('Detection failed. Try again.');
    }
  }

  void _handleError(String message) {
    setState(() {
      _detectedCurrency = message;
      _isProcessing = false;
    });
    context.read<VoiceProvider>().speak(message);
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Currency Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined, color: Colors.white),
            onPressed: () => cameraProvider.toggleFlash(),
            tooltip: 'Toggle Flash',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
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
                      // Currency frame guide
                      Center(
                        child: Container(
                          width: 260,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppTheme.ibmYellow, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Place note here',
                              style: TextStyle(
                                color: AppTheme.ibmYellow,
                                fontSize: 13,
                              ),
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

          // Result display
          if (_detectedCurrency.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.ibmYellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.ibmYellow),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _detectedCurrency,
                    style: const TextStyle(
                      color: AppTheme.ibmYellow,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.volume_up,
                        color: AppTheme.ibmYellow),
                    iconSize: 32,
                    onPressed: () {
                      final voice = _voiceMessage.isNotEmpty
                          ? _voiceMessage
                          : 'Currency: $_detectedCurrency';
                      context.read<VoiceProvider>().speak(voice);
                    },
                  ),
                ],
              ),
            ),

          // Detect button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: 'Detect currency',
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _detectCurrency,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.currency_rupee),
                label:
                    Text(_isProcessing ? 'Detecting...' : 'Detect Currency'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ibmYellow,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
