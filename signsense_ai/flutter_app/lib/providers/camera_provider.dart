import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Manages the [CameraController] lifecycle.
///
/// Resolution strategy
/// ───────────────────
/// • [ResolutionPreset.medium] (640×480 on most Android devices) is used for
///   the image-stream path. This keeps per-frame CPU work low enough for
///   20–30 FPS processing on mid-range hardware.
/// • [ImageFormatGroup.yuv420] is requested so [startImageStream] delivers
///   standard YUV420 planes on Android and BGRA8888 on iOS — both are handled
///   by [FrameConverter]. Requesting [ImageFormatGroup.jpeg] on Android causes
///   the camera HAL to hardware-encode every frame before handing it to the
///   stream callback, which adds 30–80 ms per frame and is the root cause of
///   the original silent-fail bug.
class CameraProvider extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isProcessing = false;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _isStreaming = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  FlashMode get flashMode => _flashMode;
  bool get isStreaming => _isStreaming;
  List<CameraDescription> get cameras => _cameras;

  /// The [ImageFormatGroup] the active controller was opened with.
  /// [FrameConverter] reads this to choose the correct conversion path.
  ImageFormatGroup get imageFormatGroup => ImageFormatGroup.yuv420;

  Future<void> initializeCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initializeCamera(_cameras[_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    _isInitialized = false;
    notifyListeners();

    // Dispose any existing controller first to avoid resource leaks.
    await _controller?.dispose();

    _controller = CameraController(
      camera,
      // medium = 640×480 — sufficient for YOLO/OCR inference, much cheaper
      // to convert and transfer than high (1080p) or very-high (4K).
      ResolutionPreset.medium,
      enableAudio: false,
      // yuv420: standard planar format on Android; BGRA8888 on iOS.
      // Both are handled explicitly by FrameConverter.
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Camera controller error: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    await stopImageStream();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initializeCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> toggleFlash() async {
    if (!_isInitialized || _controller == null) return;
    _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller!.setFlashMode(_flashMode);
    notifyListeners();
  }

  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      _isProcessing = true;
      notifyListeners();
      final image = await _controller!.takePicture();
      _isProcessing = false;
      notifyListeners();
      return image;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  Future<void> startImageStream(Function(CameraImage) onImage) async {
    if (!_isInitialized || _controller == null || _isStreaming) return;
    try {
      await _controller!.startImageStream(onImage);
      _isStreaming = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Stream start error: $e');
    }
  }

  Future<void> stopImageStream() async {
    if (!_isStreaming || _controller == null) return;
    try {
      await _controller!.stopImageStream();
      _isStreaming = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Stream stop error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
