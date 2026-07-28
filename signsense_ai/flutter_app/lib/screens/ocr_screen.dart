/// SignSense AI — OCR Screen
///
/// Phase A: Migrated from [ApiService] → [ApiClient].
///
/// BEFORE: Used the old ApiService._sendImage() which constructed its own
///         http.Client, had no typed exceptions, and had conflicting
///         ApiException with the core hierarchy.
///
/// AFTER:  Uses ApiClient.uploadImageFile() which:
///           • Reads base URL from AppConfig (single source of truth).
///           • Throws NetworkException / ApiException from core/errors/.
///           • Catches typed exceptions to generate the correct user message.
///
/// No UI changes were made — layout and accessibility semantics are preserved.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/voice_provider.dart';
import '../core/network/api_client.dart';
import '../core/errors/app_exception.dart';
import '../utils/app_theme.dart';

class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});

  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  final ApiClient _client = ApiClient();
  late CameraProvider _cameraProvider;
  String _extractedText = '';
  bool _isProcessing = false;

@override
void initState() {
  super.initState();

  _cameraProvider = context.read<CameraProvider>();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    _cameraProvider.initializeCameras();

    context.read<VoiceProvider>().speak(
      'Text Reader opened. Point camera at any text and tap capture.',
    );
  });
}
  Future<void> _captureAndRead() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _extractedText = '';
    });

    context.read<VoiceProvider>().speak('Capturing. Please hold still.');

    final image = await context.read<CameraProvider>().takePicture();
    if (image == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final result = kIsWeb
          ? await _client.uploadImageBytes(
              '/api/ocr/read',
              await image.readAsBytes(),
            )
          : await _client.uploadImageFile(
              '/api/ocr/read',
              image.path,
            );
      final text = result['text'] as String? ?? '';
      setState(() {
        _extractedText = text;
        _isProcessing = false;
      });

      if (text.isNotEmpty) {
        context.read<VoiceProvider>().speak(text);
      } else {
        context.read<VoiceProvider>().speak('No text found. Try again.');
      }
    } on NetworkException catch (e) {
      _handleError(e.userMessage);
    } on ApiException catch (e) {
      _handleError(e.userMessage);
    } catch (_) {
      _handleError('Error reading text. Please try again.');
    }
  }

  void _handleError(String message) {
    setState(() {
      _extractedText = message;
      _isProcessing = false;
    });
    context.read<VoiceProvider>().speak(message);
  }

@override
void dispose() {
  _client.dispose();
  _cameraProvider.stopImageStream();
  super.dispose();
}
  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Text Reader (OCR)'),
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
                ? CameraPreview(cameraProvider.controller!)
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.ibmBlue),
                  ),
          ),

          // Capture button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: 'Capture and read text',
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _captureAndRead,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(_isProcessing ? 'Processing...' : 'Capture & Read'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ),
          ),

          // Extracted text results
          if (_extractedText.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.ibmBlue, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Extracted Text',
                          style: TextStyle(
                            color: AppTheme.ibmBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up,
                              color: AppTheme.ibmBlue),
                          onPressed: () => context
                              .read<VoiceProvider>()
                              .speak(_extractedText),
                          tooltip: 'Read aloud',
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _extractedText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
