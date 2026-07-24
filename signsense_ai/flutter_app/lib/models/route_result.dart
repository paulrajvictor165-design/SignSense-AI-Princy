/// SignSense AI — Route Result Model
///
/// Phase A: Added [fromBackendJson] factory so the NavigationScreen can parse
/// the backend's flat response (route_points, instructions, distance_meters,
/// duration_seconds) instead of parsing raw ORS GeoJSON inside Flutter.
///
/// The old [fromOrsResponse] is kept for reference but is no longer called by
/// any production code — routing now goes entirely through the backend.
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> routePoints;
  final List<String> instructions;
  final double distanceMeters;
  final double durationSeconds;
  final String voiceMessage;

  const RouteResult({
    required this.routePoints,
    required this.instructions,
    required this.distanceMeters,
    required this.durationSeconds,
    this.voiceMessage = '',
  });

  /// Parse the backend /api/navigation/route response.
  ///
  /// Backend returns:
  ///   route_points     — List of {lat, lng}
  ///   instructions     — List of strings
  ///   distance_meters  — double
  ///   duration_seconds — double
  ///   voice_message    — string
  factory RouteResult.fromBackendJson(Map<String, dynamic> json) {
    final rawPoints = json['route_points'] as List? ?? [];
    final points = rawPoints.map((p) {
      final m = p as Map<String, dynamic>;
      return LatLng(
        (m['lat'] as num).toDouble(),
        (m['lng'] as num).toDouble(),
      );
    }).toList();

    final instructions = (json['instructions'] as List? ?? [])
        .map((i) => i.toString())
        .toList();

    return RouteResult(
      routePoints:     points,
      instructions:    instructions.isEmpty
          ? ['Head towards destination.', 'Continue straight.', 'You have arrived.']
          : instructions,
      distanceMeters:  (json['distance_meters'] as num?)?.toDouble()  ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      voiceMessage:    json['voice_message'] as String? ?? '',
    );
  }

  /// Legacy ORS GeoJSON parser — kept for reference, not called in production.
  factory RouteResult.fromOrsResponse(Map<String, dynamic> data) {
    final features = data['features'] as List? ?? [];
    if (features.isEmpty) {
      return const RouteResult(routePoints: [], instructions: [],
          distanceMeters: 0, durationSeconds: 0);
    }

    final feature    = features[0] as Map<String, dynamic>;
    final geometry   = feature['geometry']  as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;

    final points = coordinates.map((c) {
      final coord = c as List;
      return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
    }).toList();

    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final segments   = properties['segments'] as List? ?? [];
    final instructions = <String>[];

    for (final segment in segments) {
      final steps = (segment as Map<String, dynamic>)['steps'] as List? ?? [];
      for (final step in steps) {
        final stepMap   = step as Map<String, dynamic>;
        final instr     = stepMap['instruction'] as String? ?? '';
        final dist      = (stepMap['distance'] as num?)?.toDouble() ?? 0.0;
        if (instr.isNotEmpty) {
          instructions.add(dist > 0
              ? '$instr for ${dist.toStringAsFixed(0)} meters.'
              : instr);
        }
      }
    }

    final summary  = properties['summary'] as Map<String, dynamic>? ?? {};
    return RouteResult(
      routePoints:     points,
      instructions:    instructions.isEmpty
          ? ['Head towards destination.', 'Continue to destination.']
          : instructions,
      distanceMeters:  (summary['distance'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (summary['duration'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
