/// SignSense AI â€” Central Application Configuration
///
/// Single source of truth for all app-wide constants and configuration.
///
/// Problem solved
/// ---------------
/// Previously, the backend base URL was duplicated in two separate files:
///   â€¢ lib/services/api_service.dart      â†’ 'http://10.0.2.2:5000'
///   â€¢ lib/services/detection_service.dart â†’ 'http://10.0.2.2:5000'
///
/// Changing the server URL required editing multiple files, risking drift.
/// This class centralises every such value so there is exactly one place
/// to update when the configuration changes.
///
/// Usage
/// -----
/// ```dart
/// import '../core/config/app_config.dart';
///
/// final url = '${AppConfig.baseUrl}/api/detect/objects';
/// ```
///
/// Environment targeting
/// ----------------------
/// Switch between emulator and physical device by toggling [_useEmulator].
/// In a CI/CD pipeline this can be driven by `--dart-define=FLAVOR=staging`.
library;

class AppConfig {
  AppConfig._(); // Not instantiable â€” all members are static.

  // â”€â”€ Build-time environment toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // true  â†’ uses Android emulator loopback (10.0.2.2), which maps to the
  //         host machine's 127.0.0.1.
  //
  // false â†’ uses the LAN IP below.  Update [_deviceLanIp] to your host
  //         machine's IP address when testing on a physical device.
  //
  // For production, override with:
  //   flutter build apk --dart-define=BASE_URL=https://api.yourserver.com
  static const bool _useEmulator = false;
  static const String _deviceLanIp = '10.100.107.37'; // â† update for physical device
  static const String _productionUrl = 'https://api.signsense.ai'; // â† future

  /// Base URL of the Flask backend.
  ///
  /// This is the **only** place the URL is defined.
  /// All services import this constant â€” never hardcode the URL elsewhere.
static const String baseUrl =
    'https://signsense-ai-princy.onrender.com';
  // â”€â”€ HTTP timeouts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Timeout for standard API requests (OCR, Scene, Currency, Navigation).
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Timeout for real-time camera inference requests.
  /// Shorter than [requestTimeout] so a slow frame is dropped quickly and
  /// the next frame is processed without stalling the stream.
  static const Duration inferenceTimeout = Duration(seconds: 8);

  /// Timeout for the backend health-check probe.
  static const Duration healthCheckTimeout = Duration(seconds: 5);

  // â”€â”€ Camera pipeline â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Minimum milliseconds between voice announcements in the camera screen.
  /// Prevents TTS from speaking on every inference result (which would be
  /// a torrent of repeated speech).
  static const int voiceAnnouncementGapMs = 2500;

  /// Per-mode inference intervals (milliseconds).
  /// These mirror the server-side _kInferenceInterval map in DetectionService.
  static const Map<String, int> inferenceIntervalMs = {
    'objects': 300,
    'traffic': 300,
    'vehicles': 300,
    'faces': 600,
    'colors': 600,
    'ocr': 600,
    'currency': 600,
    'signLanguage': 300,
    'objectDetection': 300,  // dedicated Object Detection screen
  };

  // â”€â”€ Feature endpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static const String objectDetectionEndpoint = '/api/detect/objects';
  static const String sceneDescribeEndpoint    = '/api/scene/describe';
  static const String signRecognizeEndpoint    = '/api/sign/recognize';
  static const String signLandmarksEndpoint    = '/api/sign/landmarks';
  static const String currencyDetectEndpoint   = '/api/currency/detect';
  static const String healthEndpoint           = '/health';

  // â”€â”€ JPEG encoding â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Quality for camera-stream JPEG encoding (FrameConverter).
  /// 80 = ~15â€“30 KB per 640Ã—480 frame; good balance of quality and size.
  static const int streamJpegQuality = 80;

  /// Quality for static-capture JPEG encoding (OCR, Scene, Currency).
  /// Higher quality improves OCR accuracy and Gemini scene understanding.
  static const int captureJpegQuality = 92;

  // â”€â”€ Database â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Name of the local sqflite database file.
  static const String databaseName = 'signsense.db';

  /// Current database schema version.
  /// Increment this when adding new tables or columns.
  static const int databaseVersion = 1;

  // â”€â”€ App versioning â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const String appVersion = '1.0.0';
  static const String appName = 'SignSense AI';
}

