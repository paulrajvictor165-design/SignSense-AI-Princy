import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/detection_result.dart';
import '../utils/frame_converter.dart';
import '../core/config/app_config.dart';

// ─── Detection Modes ────────────────────────────────────────────────────────

/// All detection modes understood by the backend.
///
/// Modes beyond the original five are reserved for future pipeline modules
/// (Task 3 onwards) and are wired to endpoints but do not require any changes
/// to this file when the backend endpoints are added.
enum DetectionMode {
  objects('Objects', '/api/detect/objects'),
  traffic('Traffic', '/api/detect/traffic'),
  vehicles('Vehicles', '/api/detect/vehicles'),
  faces('Faces', '/api/detect/faces'),
  colors('Colors', '/api/detect/colors'),
  // ── Future modules ────────────────────────────────────────────────────────
  // Endpoints will be created in later tasks; added here now so CameraScreen
  // can reference them without a breaking change to this file.
  ocr('Read Text', '/api/ocr/read'),
  currency('Currency', '/api/currency/detect'),
  signLanguage('Sign Language', '/api/sign/recognize');

  const DetectionMode(this.label, this.endpoint);

  /// Human-readable label shown in the mode-selector chip bar.
  final String label;

  /// Flask backend endpoint for this mode.
  final String endpoint;
}

// ─── Per-mode inference intervals ───────────────────────────────────────────
//
// Different tasks require different processing cadences:
//
//   • Objects / Traffic / Vehicles — need near-real-time updates for safety.
//     300 ms ≈ 3.3 inferences/sec, keeps server load manageable.
//   • Faces / Colors / OCR / Currency — change slowly; 600 ms is sufficient.
//   • Sign Language — continuous, similar to objects.
//
// The stream itself runs at the camera's native rate (≥30 FPS at medium
// resolution on most devices).  The interval below is the *minimum time*
// between backend calls — frames arriving sooner are silently dropped by the
// token-bucket in [DetectionService].

const Map<DetectionMode, Duration> _kInferenceInterval = {
  DetectionMode.objects: Duration(milliseconds: 300),
  DetectionMode.traffic: Duration(milliseconds: 300),
  DetectionMode.vehicles: Duration(milliseconds: 300),
  DetectionMode.faces: Duration(milliseconds: 600),
  DetectionMode.colors: Duration(milliseconds: 600),
  DetectionMode.ocr: Duration(milliseconds: 600),
  DetectionMode.currency: Duration(milliseconds: 600),
  DetectionMode.signLanguage: Duration(milliseconds: 300),
};

// ─── DetectionService ────────────────────────────────────────────────────────

/// Processes [CameraImage] frames from the live stream and submits them to the
/// Flask backend for inference.
///
/// Throttling strategy — token bucket
/// ────────────────────────────────────
/// The camera stream can deliver 30+ frames per second.  Sending every frame
/// to the server would saturate even a local network and produce no better UX
/// than 3–4 inferences per second (human perception of object-position updates
/// plateaus well below 10 FPS).
///
/// We use a simple single-token bucket:
///   1. A flag [_busy] tracks whether an HTTP request is in-flight.
///   2. A [DateTime] timestamp records when the last request *completed*.
///   3. Incoming frames are dropped if either the flag is set OR the elapsed
///      time since the last completion is below [_kInferenceInterval] for the
///      current mode.
///
/// This guarantees:
///   • At most one outstanding HTTP request at any time (no queue build-up).
///   • A minimum rest period between calls even if the network is very fast.
///   • The UI thread is never blocked — conversion runs in a background isolate.
///
/// Backend URL
/// ─────────────
/// The base URL is kept in a single place here.  For production, inject it via
/// a compile-time environment variable or a config file.  For now it matches
/// the emulator loopback used across the project.
class DetectionService {
  /// Base URL of the Flask backend — sourced from [AppConfig.baseUrl].
  /// Change the URL once in app_config.dart; all services update automatically.
  static String get _baseUrl => AppConfig.baseUrl;

  /// HTTP timeout per inference request.
  static const Duration _requestTimeout = AppConfig.inferenceTimeout;

  // Token-bucket state
  bool _busy = false;
  DateTime _lastCompleted = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Process one frame from the camera stream.
  ///
  /// Returns a (possibly empty) list of [DetectionResult]s.  Returns an empty
  /// list immediately if throttling drops the frame or an error occurs — the
  /// caller should treat an empty list as "no update this tick" rather than
  /// "nothing detected".
  Future<List<DetectionResult>> detectFromCameraImage(
    CameraImage image, {
    DetectionMode mode = DetectionMode.objects,
  }) async {
    // ── Token-bucket check ────────────────────────────────────────────────
    if (_busy) return const [];

    final interval =
        _kInferenceInterval[mode] ?? const Duration(milliseconds: 300);
    final elapsed = DateTime.now().difference(_lastCompleted);
    if (elapsed < interval) return const [];

    _busy = true;

    try {
      // ── Frame conversion (background isolate) ─────────────────────────
      final Uint8List? jpegBytes =
          await FrameConverter.convertInBackground(image);

      if (jpegBytes == null || jpegBytes.isEmpty) {
        _busy = false;
        return const [];
      }

      // ── HTTP multipart request ────────────────────────────────────────
      final List<DetectionResult> results =
          await _sendJpeg(jpegBytes, mode.endpoint);

      _lastCompleted = DateTime.now();
      _busy = false;
      return results;
    } catch (_) {
      // Silent per-frame failure — stream must never throw to the caller.
      _busy = false;
      return const [];
    }
  }

  /// Send already-encoded JPEG bytes to [endpoint] and parse the response.
  ///
  /// This method is also called directly from static screens (OCR, Currency,
  /// Scene) that capture a full image rather than streaming.
  Future<List<DetectionResult>> sendJpegBytes(
    Uint8List jpegBytes,
    DetectionMode mode,
  ) async {
    return _sendJpeg(jpegBytes, mode.endpoint);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<List<DetectionResult>> _sendJpeg(
    Uint8List jpegBytes,
    String endpoint,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl$endpoint'),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        jpegBytes,
        filename: 'frame.jpg',
        // Explicitly declare MIME type so Flask's request.files MIME check
        // does not reject the upload.
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamedResponse = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // All detection endpoints return a top-level "detections" list.
    // OCR and currency endpoints return different shapes — callers that need
    // those shapes should use ApiService directly; here we return an empty
    // list so CameraScreen still compiles cleanly for those mode values.
    final rawList = data['detections'] as List<dynamic>?;
    if (rawList == null) return const [];

    return rawList
        .map((d) => DetectionResult.fromJson(d as Map<String, dynamic>))
        .toList();
  }
}
