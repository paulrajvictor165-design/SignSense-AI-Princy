import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraProvider extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isProcessing = false;
  bool _isStreaming = false;
  bool _isDisposed = false;

  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  CameraController? get controller => _controller;

  List<CameraDescription> get cameras =>
      List.unmodifiable(_cameras);

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isProcessing => _isProcessing;
  bool get isStreaming => _isStreaming;

  FlashMode get flashMode => _flashMode;

  ImageFormatGroup get imageFormatGroup {
    if (kIsWeb) {
      return ImageFormatGroup.unknown;
    }

    return ImageFormatGroup.yuv420;
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> initializeCameras() async {
    if (_isDisposed || _isInitializing) {
      return;
    }

    final currentController = _controller;

    if (_isInitialized &&
        currentController != null &&
        currentController.value.isInitialized) {
      return;
    }

    _isInitializing = true;
    _isInitialized = false;
    _safeNotifyListeners();

    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        debugPrint('No cameras found.');
        return;
      }

      _selectedCameraIndex = _findDefaultCameraIndex();

      await _initializeCamera(
        _cameras[_selectedCameraIndex],
      );
    } on CameraException catch (error) {
      debugPrint(
        'Camera initialization error: '
        '${error.code} - ${error.description}',
      );
    } catch (error) {
      debugPrint(
        'Camera initialization error: $error',
      );
    } finally {
      _isInitializing = false;
      _safeNotifyListeners();
    }
  }

  int _findDefaultCameraIndex() {
    if (_cameras.isEmpty) {
      return 0;
    }

    if (kIsWeb) {
      final frontCameraIndex = _cameras.indexWhere(
        (camera) =>
            camera.lensDirection ==
            CameraLensDirection.front,
      );

      if (frontCameraIndex >= 0) {
        return frontCameraIndex;
      }

      return 0;
    }

    final backCameraIndex = _cameras.indexWhere(
      (camera) =>
          camera.lensDirection ==
          CameraLensDirection.back,
    );

    if (backCameraIndex >= 0) {
      return backCameraIndex;
    }

    return 0;
  }

  Future<void> _initializeCamera(
    CameraDescription camera,
  ) async {
    if (_isDisposed) {
      return;
    }

    _isInitialized = false;
    _isStreaming = false;
    _safeNotifyListeners();

    final oldController = _controller;
    _controller = null;

    if (oldController != null) {
      try {
        if (!kIsWeb &&
            oldController.value.isStreamingImages) {
          await oldController.stopImageStream();
        }
      } catch (error) {
        debugPrint(
          'Old stream stop error: $error',
        );
      }

      try {
        await oldController.dispose();
      } catch (error) {
        debugPrint(
          'Old controller dispose error: $error',
        );
      }
    }

    final CameraController newController;

    if (kIsWeb) {
      newController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
    } else {
      newController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
    }

    _controller = newController;

    try {
      await newController.initialize();

      if (_isDisposed) {
        await newController.dispose();
        return;
      }

      if (!kIsWeb) {
        try {
          await newController.setFlashMode(
            _flashMode,
          );
        } on CameraException catch (error) {
          debugPrint(
            'Flash unavailable: '
            '${error.code} - ${error.description}',
          );
        }
      }

      _isInitialized =
          newController.value.isInitialized;

      _safeNotifyListeners();
    } on CameraException catch (error) {
      _isInitialized = false;
      _isStreaming = false;

      debugPrint(
        'Camera controller error: '
        '${error.code} - ${error.description}',
      );

      try {
        await newController.dispose();
      } catch (_) {}

      if (identical(
        _controller,
        newController,
      )) {
        _controller = null;
      }

      _safeNotifyListeners();
    } catch (error) {
      _isInitialized = false;
      _isStreaming = false;

      debugPrint(
        'Camera controller error: $error',
      );

      try {
        await newController.dispose();
      } catch (_) {}

      if (identical(
        _controller,
        newController,
      )) {
        _controller = null;
      }

      _safeNotifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (_isDisposed ||
        _isInitializing ||
        _cameras.length < 2) {
      return;
    }

    _isInitializing = true;
    _safeNotifyListeners();

    try {
      if (!kIsWeb) {
        await stopImageStream();
      }

      _selectedCameraIndex =
          (_selectedCameraIndex + 1) %
          _cameras.length;

      await _initializeCamera(
        _cameras[_selectedCameraIndex],
      );
    } catch (error) {
      debugPrint(
        'Switch camera error: $error',
      );
    } finally {
      _isInitializing = false;
      _safeNotifyListeners();
    }
  }

  Future<void> toggleFlash() async {
    if (_isDisposed || kIsWeb) {
      return;
    }

    final currentController = _controller;

    if (!_isInitialized ||
        currentController == null ||
        !currentController.value.isInitialized) {
      return;
    }

    final nextFlashMode =
        _flashMode == FlashMode.off
            ? FlashMode.torch
            : FlashMode.off;

    try {
      await currentController.setFlashMode(
        nextFlashMode,
      );

      _flashMode = nextFlashMode;
      _safeNotifyListeners();
    } on CameraException catch (error) {
      debugPrint(
        'Flash error: '
        '${error.code} - ${error.description}',
      );
    } catch (error) {
      debugPrint(
        'Flash error: $error',
      );
    }
  }

  Future<XFile?> takePicture() async {
    if (_isDisposed) {
      return null;
    }

    final currentController = _controller;

    if (!_isInitialized ||
        currentController == null ||
        !currentController.value.isInitialized ||
        currentController.value.isTakingPicture) {
      return null;
    }

    try {
      _isProcessing = true;
      _safeNotifyListeners();

      return await currentController.takePicture();
    } on CameraException catch (error) {
      debugPrint(
        'Take picture error: '
        '${error.code} - ${error.description}',
      );

      return null;
    } catch (error) {
      debugPrint(
        'Take picture error: $error',
      );

      return null;
    } finally {
      _isProcessing = false;
      _safeNotifyListeners();
    }
  }

  void setProcessing(bool value) {
    if (_isDisposed ||
        _isProcessing == value) {
      return;
    }

    _isProcessing = value;
    _safeNotifyListeners();
  }

  Future<void> startImageStream(
    void Function(CameraImage image) onImage,
  ) async {
    /*
      IMPORTANT:

      camera_web does not support CameraImage
      continuous image streaming.

      On web, this function silently returns.
      No repeated console message will be printed.
    */

    if (_isDisposed || kIsWeb) {
      return;
    }

    final currentController = _controller;

    if (!_isInitialized ||
        currentController == null ||
        !currentController.value.isInitialized ||
        _isStreaming ||
        currentController.value.isStreamingImages) {
      return;
    }

    try {
      await currentController.startImageStream(
        onImage,
      );

      _isStreaming = true;
      _safeNotifyListeners();
    } on CameraException catch (error) {
      _isStreaming = false;

      debugPrint(
        'Stream start error: '
        '${error.code} - ${error.description}',
      );

      _safeNotifyListeners();
    } catch (error) {
      _isStreaming = false;

      debugPrint(
        'Stream start error: $error',
      );

      _safeNotifyListeners();
    }
  }

  Future<void> stopImageStream() async {
    if (_isDisposed) {
      return;
    }

    /*
      Web-la stream start pannave maatom.
      Athanala direct-aa return pannalam.
    */

    if (kIsWeb) {
      if (_isStreaming) {
        _isStreaming = false;
        _safeNotifyListeners();
      }

      return;
    }

    final currentController = _controller;

    if (currentController == null) {
      _isStreaming = false;
      return;
    }

    if (!_isStreaming &&
        !currentController.value.isStreamingImages) {
      return;
    }

    try {
      await currentController.stopImageStream();
    } on CameraException catch (error) {
      debugPrint(
        'Stream stop error: '
        '${error.code} - ${error.description}',
      );
    } catch (error) {
      debugPrint(
        'Stream stop error: $error',
      );
    } finally {
      _isStreaming = false;
      _safeNotifyListeners();
    }
  }

  Future<void> disposeCamera() async {
    if (_isDisposed) {
      return;
    }

    final currentController = _controller;

    _controller = null;
    _isInitialized = false;
    _isStreaming = false;
    _isProcessing = false;

    if (currentController != null) {
      try {
        if (!kIsWeb &&
            currentController.value.isStreamingImages) {
          await currentController.stopImageStream();
        }
      } catch (error) {
        debugPrint(
          'Dispose stream error: $error',
        );
      }

      try {
        await currentController.dispose();
      } catch (error) {
        debugPrint(
          'Dispose controller error: $error',
        );
      }
    }

    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;

    final currentController = _controller;

    _controller = null;
    _isInitialized = false;
    _isStreaming = false;
    _isProcessing = false;

    currentController?.dispose();

    super.dispose();
  }
}