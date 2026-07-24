/// SignSense AI — Typed Exception Hierarchy
///
/// Problem solved
/// ---------------
/// The original code used bare `Exception` and `ApiException` throughout.
/// Flutter screens had to match on string message prefixes to determine what
/// kind of error occurred and what to tell the user — fragile and untestable.
///
/// This module provides:
/// • A base class [AppException] that every SignSense error extends.
/// • Typed subclasses for each error category (network, camera, AI, etc.).
/// • A [userMessage] getter on every exception — a human-readable string
///   suitable for TTS and on-screen display, never a technical stack trace.
/// • A [developerMessage] getter for logs — technical detail for the engineer.
///
/// Usage
/// -----
/// ```dart
/// try {
///   final result = await apiClient.post('/api/detect/objects', ...);
/// } on NetworkException catch (e) {
///   voiceProvider.speak(e.userMessage);
///   logger.warning(e.developerMessage);
/// } on ApiException catch (e) {
///   if (e.statusCode == 413) {
///     voiceProvider.speak('Image is too large. Please try again.');
///   } else {
///     voiceProvider.speak(e.userMessage);
///   }
/// }
/// ```
library;

// ── Base exception ─────────────────────────────────────────────────────────

/// Base class for all SignSense AI application exceptions.
///
/// Every subclass must provide:
/// • [userMessage] — shown in UI / spoken via TTS; never technical.
/// • [developerMessage] — logged server-side; may contain technical detail.
abstract class AppException implements Exception {
  const AppException();

  /// A human-readable message suitable for display to the end user or TTS.
  /// Must be clear, non-technical, and actionable.
  String get userMessage;

  /// A developer-facing message containing technical context for logging.
  /// Must NEVER be shown to the end user.
  String get developerMessage;

  @override
  String toString() => 'AppException(${runtimeType}): $developerMessage';
}

// ── Network exceptions ────────────────────────────────────────────────────

/// Thrown when the HTTP request fails at the transport layer.
///
/// Examples:
/// • No internet connection.
/// • Request timed out.
/// • Server unreachable (connection refused).
class NetworkException extends AppException {
  final String detail;
  final bool isTimeout;

  const NetworkException({
    required this.detail,
    this.isTimeout = false,
  });

  @override
  String get userMessage => isTimeout
      ? 'Request timed out. Check your internet connection and try again.'
      : 'Network error. Check your connection and try again.';

  @override
  String get developerMessage => 'NetworkException: $detail';
}

// ── API / Backend exceptions ──────────────────────────────────────────────

/// Thrown when the Flask backend returns a non-200 HTTP status.
///
/// Carries the structured error envelope returned by the backend
/// error_handler middleware so the caller can act on the error code.
class ApiException extends AppException {
  /// HTTP status code returned by the server.
  final int statusCode;

  /// Machine-readable error code from the backend envelope
  /// (e.g. "VALIDATION_ERROR", "AI_SERVICE_ERROR").
  final String errorCode;

  /// Human-readable message from the backend envelope.
  final String serverMessage;

  const ApiException({
    required this.statusCode,
    required this.errorCode,
    required this.serverMessage,
  });

  @override
  String get userMessage {
    switch (statusCode) {
      case 400:
        return 'Invalid request. $serverMessage';
      case 413:
        return 'Image is too large. Please use a smaller image.';
      case 404:
        return 'Service not found. Please update the app.';
      case 500:
        return 'Server error. Please try again in a moment.';
      default:
        return serverMessage.isNotEmpty
            ? serverMessage
            : 'Something went wrong. Please try again.';
    }
  }

  @override
  String get developerMessage =>
      'ApiException: status=$statusCode  code=$errorCode  msg=$serverMessage';
}

// ── Camera exceptions ─────────────────────────────────────────────────────

/// Thrown when a camera operation fails.
///
/// Examples:
/// • Camera permission denied.
/// • Camera hardware unavailable.
/// • Camera controller not initialized.
class CameraException extends AppException {
  final String detail;
  final bool isPermissionDenied;

  const CameraException({
    required this.detail,
    this.isPermissionDenied = false,
  });

  @override
  String get userMessage => isPermissionDenied
      ? 'Camera permission denied. Please allow camera access in Settings.'
      : 'Camera is not available. Please restart the app.';

  @override
  String get developerMessage => 'CameraException: $detail';
}

// ── Permission exceptions ─────────────────────────────────────────────────

/// Thrown when a required device permission (location, camera, microphone)
/// has not been granted.
class PermissionException extends AppException {
  final String permissionName;

  const PermissionException({required this.permissionName});

  @override
  String get userMessage =>
      '$permissionName permission is required. '
      'Please allow it in your device Settings and restart the app.';

  @override
  String get developerMessage =>
      'PermissionException: $permissionName not granted';
}

// ── AI / Processing exceptions ────────────────────────────────────────────

/// Thrown when an AI service (YOLO, OCR, Gemini) fails to produce a result.
///
/// This is distinct from [ApiException] because the HTTP request succeeded
/// (200 OK) but the AI pipeline returned no usable output.
class AiServiceException extends AppException {
  final String service; // e.g. "YOLO", "EasyOCR", "Gemini"
  final String detail;

  const AiServiceException({
    required this.service,
    required this.detail,
  });

  @override
  String get userMessage =>
      'AI analysis failed. Please try again.';

  @override
  String get developerMessage => 'AiServiceException[$service]: $detail';
}

// ── Frame conversion exceptions ───────────────────────────────────────────

/// Thrown when [FrameConverter] cannot convert a [CameraImage] to JPEG.
///
/// This is a recoverable error in the stream — the frame is dropped and
/// the next frame is processed normally.  Should be logged but not shown
/// to the user.
class FrameConversionException extends AppException {
  final String detail;

  const FrameConversionException({required this.detail});

  @override
  String get userMessage =>
      ''; // Never shown — stream silently drops the frame.

  @override
  String get developerMessage => 'FrameConversionException: $detail';
}

// ── Navigation exceptions ─────────────────────────────────────────────────

/// Thrown when route calculation or geocoding fails.
class NavigationException extends AppException {
  final String detail;

  const NavigationException({required this.detail});

  @override
  String get userMessage =>
      'Could not find a route. Check the destination and try again.';

  @override
  String get developerMessage => 'NavigationException: $detail';
}
