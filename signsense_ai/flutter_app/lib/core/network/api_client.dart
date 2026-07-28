/// SignSense AI — Central HTTP API Client
///
/// Problem solved
/// ---------------
/// The project previously had two separate HTTP client instances:
///   • [ApiService] (http.Client) — used by all static screens
///   • [DetectionService] (http.MultipartRequest) — used by camera stream
///
/// Both hardcoded 'http://10.0.2.2:5000'.  Both had separate timeout values.
/// Both had their own error handling.  Neither used the typed exception
/// hierarchy.
///
/// This class is the single HTTP client for the entire application.
/// All services use it — they never construct [http.Client] themselves.
///
/// Features
/// --------
/// • Single base URL from [AppConfig.baseUrl].
/// • Typed exceptions: [NetworkException] / [ApiException] from core/errors/.
/// • Consistent timeout handling.
/// • Standard response parsing: reads the backend's JSON envelope
///   {"success": bool, "data": {...}} and unwraps the payload.
/// • Multipart image upload helper used by all camera-based features.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';

/// Central HTTP client.
///
/// Create one instance per service class (they each hold a reference to the
/// same underlying [http.Client] via the singleton getter or DI).
///
/// All public methods:
///   • Return the parsed response body on success (Map or List).
///   • Throw a typed [AppException] subclass on failure — never a raw
///     [Exception] or [String].
class ApiClient {
  ApiClient() : _client = http.Client();

  final http.Client _client;

  // ── JSON POST ─────────────────────────────────────────────────────────────

  /// Send a JSON POST request and return the parsed response body.
  ///
  /// Throws [NetworkException] on transport failure, [ApiException] on
  /// non-200 HTTP status.
  Future<Map<String, dynamic>> postJson(
    String endpoint,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout ?? AppConfig.requestTimeout);

      return _parseResponse(response);
    } on TimeoutException {
      throw const NetworkException(
        detail: 'postJson timed out',
        isTimeout: true,
      );
    } on SocketException catch (e) {
      throw NetworkException(
        detail: 'SocketException on postJson: $e',
      );
    }
  }

  // ── GET ───────────────────────────────────────────────────────────────────

  /// Send a GET request and return the parsed response body.
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? timeout,
  }) async {
    Uri uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    try {
      final response = await _client
          .get(uri)
          .timeout(timeout ?? AppConfig.requestTimeout);

      return _parseResponse(response);
    } on TimeoutException {
      throw const NetworkException(
        detail: 'GET timed out',
        isTimeout: true,
      );
    } on SocketException catch (e) {
      throw NetworkException(detail: 'SocketException on GET: $e');
    }
  }

  // ── Multipart image upload ────────────────────────────────────────────────

  /// Upload a JPEG image file from [imagePath] to [endpoint].
  ///
  /// Used by static-capture screens: OCR, Currency, Scene Description.
  /// Returns the parsed response body.
  Future<Map<String, dynamic>> uploadImageFile(
    String endpoint,
    String imagePath, {
    Duration? timeout,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Browser captures must be uploaded with uploadImageBytes().',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imagePath,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    return _sendMultipart(request, timeout ?? AppConfig.requestTimeout);
  }

  /// Upload raw JPEG bytes to [endpoint].
  ///
  /// Used by the real-time camera stream (DetectionService) where the image
  /// is already in memory as [Uint8List] — no file path involved.
  Future<Map<String, dynamic>> uploadImageBytes(
    String endpoint,
    List<int> jpegBytes, {
    Duration? timeout,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        jpegBytes,
        filename: 'frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    return _sendMultipart(request, timeout ?? AppConfig.requestTimeout);
  }

  // ── Health check ──────────────────────────────────────────────────────────

  /// Returns true when the backend responds with HTTP 200 on /health.
  /// Used by screens to display a "server offline" warning.
  Future<bool> isServerAlive() async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}${AppConfig.healthEndpoint}',
    );

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client.get(
          uri,
          headers: const {'Accept': 'application/json'},
        ).timeout(AppConfig.healthCheckTimeout);

        if (response.statusCode != 200) {
          if (attempt == 1) return false;
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }

        final decoded = jsonDecode(response.body);
        final status = decoded is Map<String, dynamic>
            ? decoded['status']
            : null;
        if (status == 'healthy' || status == 'ok') {
          return true;
        }

        return false;
      } on TimeoutException {
        if (attempt == 1) return false;
      } on http.ClientException {
        if (attempt == 1) return false;
      } on SocketException {
        if (attempt == 1) return false;
      } on FormatException {
        return false;
      } catch (_) {
        return false;
      }

      await Future<void>.delayed(const Duration(seconds: 1));
    }

    return false;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  /// Release the underlying HTTP client.
  /// Call this when the owning service is disposed.
  void dispose() => _client.close();

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _sendMultipart(
    http.MultipartRequest request,
    Duration timeout,
  ) async {
    try {
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('Multipart response status: ${response.statusCode}');
      return _parseResponse(response);
    } on TimeoutException {
      debugPrint('Multipart upload timed out after ${timeout.inSeconds}s.');
      throw const NetworkException(
        detail: 'Multipart upload timed out',
        isTimeout: true,
      );
    } on SocketException catch (e) {
      debugPrint('Multipart network error: $e');
      throw NetworkException(detail: 'SocketException on multipart: $e');
    } on http.ClientException catch (e) {
      debugPrint('Multipart client/network error: $e');
      throw NetworkException(detail: 'ClientException on multipart: $e');
    }
  }

  /// Parse an HTTP response into a Dart map.
  ///
  /// Handles both the new standard envelope and the legacy flat response
  /// shape (for backward compatibility while routes are being migrated).
  ///
  /// Throws [ApiException] on non-200 status.
  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          // If the backend already wraps in the standard envelope, unwrap.
          if (decoded.containsKey('success') && decoded.containsKey('data')) {
            final data = decoded['data'];
            if (data is Map<String, dynamic>) return data;
          }
          // Legacy flat response — return as-is.
          return decoded;
        }
        return {'result': decoded};
      } on FormatException catch (e) {
        debugPrint('Invalid JSON response: $e');
        return {'raw': response.body};
      }
    }

    // Non-2xx — parse error envelope.
    String errorCode = 'UNKNOWN_ERROR';
    String serverMessage = 'Request failed with status ${response.statusCode}.';
    debugPrint('Backend error ${response.statusCode}: ${response.body}');

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final errorBlock = body['error'] as Map<String, dynamic>?;
      if (errorBlock != null) {
        errorCode    = errorBlock['code']    as String? ?? errorCode;
        serverMessage = errorBlock['message'] as String? ?? serverMessage;
      }
    } on FormatException catch (e) {
      debugPrint('Invalid backend error JSON: $e');
      // Could not parse error body — use defaults.
    }

    throw ApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      serverMessage: serverMessage,
    );
  }
}
