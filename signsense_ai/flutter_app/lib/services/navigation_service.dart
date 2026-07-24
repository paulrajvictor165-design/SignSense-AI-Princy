/// SignSense AI — Navigation Service
///
/// Phase A rewrite — security fix
/// --------------------------------
/// BEFORE: Flutter called Nominatim (geocoding) and OpenRouteService (routing)
///         directly from the app.  The ORS API key was embedded in the APK via
///         String.fromEnvironment('ORS_API_KEY', defaultValue: 'YOUR_ORS_API_KEY').
///         This is a security issue — any one who decompiles the APK can extract
///         the API key.
///
/// AFTER:  Flutter delegates 100% of geocoding and routing to the backend.
///         The backend holds the ORS key in a .env file (never in the APK).
///         This class is now a thin wrapper around [ApiClient.postJson].
///
/// API contract: POST /api/navigation/route
///   Body  → { start_lat, start_lng, destination }
///   Reply → RouteResult shape parsed by RouteResult.fromBackendJson()
///
/// The [NavigationException] class from this file is removed — the canonical
/// one lives in core/errors/app_exception.dart.

import '../core/network/api_client.dart';
import '../core/errors/app_exception.dart';
import '../models/route_result.dart';

class NavigationService {
  NavigationService() : _client = ApiClient();

  final ApiClient _client;

  /// Get a walking route from [startLat]/[startLng] to a named [destination].
  ///
  /// Throws [NavigationException] when the backend cannot geocode the place.
  /// Throws [NetworkException] on transport failure.
  /// Throws [ApiException] on backend error responses.
  Future<RouteResult> getRoute({
    required double startLat,
    required double startLng,
    required String destination,
  }) async {
    final data = await _client.postJson(
      '/api/navigation/route',
      {
        'start_lat': startLat,
        'start_lng': startLng,
        'destination': destination,
      },
      timeout: const Duration(seconds: 30),
    );

    // Backend returns success:false with a message when geocoding fails
    if (data['success'] == false || data.containsKey('error')) {
      throw NavigationException(
        detail: data['message']?.toString() ??
            'Backend could not find destination: $destination',
      );
    }

    return RouteResult.fromBackendJson(data);
  }

  void dispose() => _client.dispose();
}
