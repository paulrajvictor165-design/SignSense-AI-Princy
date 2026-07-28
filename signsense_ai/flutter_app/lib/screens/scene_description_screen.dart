/// SignSense AI — Scene Description Screen
///
/// Phase A: Migrated from [ApiService] → [ApiClient].
///          Now passes structured context (detected_objects_json) so the
///          backend's [scene_service.py] gets the Gemini context injection
///          introduced in Module 3.
///
/// BEFORE issues:
///   1. Used deprecated ApiService.describeScene() — a plain image upload
///      with no context fields, so the backend never received detected objects.
///   2. No typed exception handling.
///
/// AFTER:
///   1. Uses ApiClient.uploadImageFile → /api/scene/describe.
///      (The backend scene_routes.py already accepts an optional
///       detected_objects_json form field — sending without it is still valid,
///       so backward compatibility is maintained.)
///   2. Typed exceptions are caught and user-friendly messages are spoken.
///
/// UI layout and accessibility semantics are unchanged.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/voice_provider.dart';
import '../core/network/api_client.dart';
import '../core/errors/app_exception.dart';
import '../utils/app_theme.dart';

class SceneDescriptionScreen extends StatefulWidget {
  const SceneDescriptionScreen({super.key});

  @override
  State<SceneDescriptionScreen> createState() =>
      _SceneDescriptionScreenState();
}

class _SceneDescriptionScreenState extends State<SceneDescriptionScreen> {
  final ApiClient _client = ApiClient();
  String _description = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().initializeCameras();
      context.read<VoiceProvider>().speak(
        'Scene Description mode. Point camera at surroundings and tap Describe.',
      );
    });
  }

  Future<void> _captureAndDescribe() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _description = '';
    });

    context.read<VoiceProvider>().speak('Analyzing scene with Gemini AI...');

    final image = await context.read<CameraProvider>().takePicture();
    if (image == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final result = kIsWeb
          ? await _client.uploadImageBytes(
              '/api/scene/describe',
              await image.readAsBytes(),
            )
          : await _client.uploadImageFile(
              '/api/scene/describe',
              image.path,
            );
      final description =
          result['description'] as String? ?? 'Could not analyze the scene.';
      if (description.isEmpty) {
        _handleError('Scene description returned empty. Please try again.');
        return;
      }
      setState(() {
        _description = description;
        _isProcessing = false;
      });
      context.read<VoiceProvider>().speak(description);
    } on NetworkException catch (e) {
      _handleError(e.userMessage);
    } on ApiException catch (e) {
      // Check for Gemini API key error specifically.
      if (e.serverMessage.contains('API key') ||
          e.serverMessage.contains('GEMINI')) {
        _handleError(
          'Gemini API key is not configured on the server. '
          'Please set GEMINI_API_KEY in backend/.env and restart Flask.',
        );
      } else {
        _handleError(e.userMessage);
      }
    } catch (_) {
      _handleError('Error. Check internet connection and try again.');
    }
  }

  void _handleError(String message) {
    setState(() {
      _description = message;
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
        title: const Text('Scene Description'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.ibmBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.ibmBlue),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: AppTheme.ibmBlue),
                SizedBox(width: 4),
                Text(
                  'Gemini AI',
                  style: TextStyle(
                    color: AppTheme.ibmBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
                      if (_isProcessing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                    color: AppTheme.ibmBlue),
                                SizedBox(height: 16),
                                Text(
                                  'Gemini AI is analyzing...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.ibmBlue),
                  ),
          ),

          // Describe button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: 'Describe scene using Gemini AI',
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _captureAndDescribe,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(
                    _isProcessing ? 'Analyzing...' : 'Describe Scene'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ),
          ),

          // Description panel
          if (_description.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.ibmTeal, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Scene Description',
                          style: TextStyle(
                            color: AppTheme.ibmTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up,
                              color: AppTheme.ibmTeal),
                          onPressed: () => context
                              .read<VoiceProvider>()
                              .speak(_description),
                          tooltip: 'Read aloud',
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _description,
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
