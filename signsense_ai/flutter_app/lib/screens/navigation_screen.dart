/// SignSense AI — Navigation Screen
///
/// Phase A: Migrated from [NavigationService] (which called ORS/Nominatim
///          directly from Flutter) to the rewritten [NavigationService] that
///          delegates everything to the backend via [ApiClient].
///
/// Key changes:
///   1. [NavigationService.getRoute] now calls POST /api/navigation/route.
///   2. Response is parsed by [RouteResult.fromBackendJson] — route_points,
///      instructions, distance_meters, duration_seconds, voice_message.
///   3. voice_message from the backend is spoken when route is found.
///   4. Typed exceptions (NavigationException, NetworkException, ApiException)
///      are caught and spoken to the user.
///   5. The old import of NavigationException from services/ removed — now
///      uses core/errors/app_exception.dart canonical class.
///
/// UI layout, map rendering, and step-advance logic are unchanged.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/voice_provider.dart';
import '../services/navigation_service.dart';
import '../core/errors/app_exception.dart';
import '../utils/app_theme.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final NavigationService _navService = NavigationService();
  final MapController _mapController = MapController();
  final TextEditingController _destinationController = TextEditingController();

  Position? _currentPosition;
  List<LatLng> _routePoints = [];
  List<String> _instructions = [];
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  bool _isLoading = false;
  String _currentInstruction = 'Enter destination to begin navigation.';

  @override
  void initState() {
    super.initState();
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceProvider>().speak(
        'Navigation mode. Enter your destination to start.',
      );
    });
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {});

      // Track live position
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        setState(() => _currentPosition = pos);
        if (_isNavigating) _updateNavigation(pos);
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _startNavigation() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty || _currentPosition == null) {
      context.read<VoiceProvider>().speak('Please enter a destination.');
      return;
    }

    setState(() => _isLoading = true);
    context.read<VoiceProvider>().speak('Searching route to $destination');

    try {
      final result = await _navService.getRoute(
        startLat: _currentPosition!.latitude,
        startLng: _currentPosition!.longitude,
        destination: destination,
      );

      setState(() {
        _routePoints = result.routePoints;
        _instructions = result.instructions;
        _currentStepIndex = 0;
        _currentInstruction =
            _instructions.isNotEmpty ? _instructions[0] : 'Follow the route.';
        _isNavigating = true;
        _isLoading = false;
      });

      // Prefer the backend-crafted voice message; fall back to step count
      final announcement = result.voiceMessage.isNotEmpty
          ? result.voiceMessage
          : 'Route found. ${_instructions.length} steps. $_currentInstruction';
      context.read<VoiceProvider>().speak(announcement);
    } on NavigationException catch (e) {
      setState(() => _isLoading = false);
      context.read<VoiceProvider>().speak(e.userMessage);
    } on NetworkException catch (e) {
      setState(() => _isLoading = false);
      context.read<VoiceProvider>().speak(e.userMessage);
    } on ApiException catch (e) {
      setState(() => _isLoading = false);
      context.read<VoiceProvider>().speak(e.userMessage);
    } catch (_) {
      setState(() => _isLoading = false);
      context.read<VoiceProvider>().speak(
        'Could not find route. Check internet and try again.',
      );
    }
  }

  void _updateNavigation(Position position) {
    if (_routePoints.isEmpty || _currentStepIndex >= _instructions.length) {
      return;
    }

    final nextPoint = _routePoints[
        (_currentStepIndex + 1).clamp(0, _routePoints.length - 1)];
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );

    if (distance < 20 && _currentStepIndex < _instructions.length - 1) {
      setState(() {
        _currentStepIndex++;
        _currentInstruction = _instructions[_currentStepIndex];
      });
      context.read<VoiceProvider>().speak(_currentInstruction);
    }
  }

  void _nextInstruction() {
    if (_currentStepIndex < _instructions.length - 1) {
      setState(() {
        _currentStepIndex++;
        _currentInstruction = _instructions[_currentStepIndex];
      });
      context.read<VoiceProvider>().speak(_currentInstruction);
    } else {
      context.read<VoiceProvider>().speak('You have reached your destination.');
    }
  }

  void _repeatInstruction() {
    context.read<VoiceProvider>().speak(_currentInstruction);
  }

  @override
  void dispose() {
    _navService.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: Column(
        children: [
          // Destination input
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Enter destination',
                    child: TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        hintText: 'Enter destination...',
                        prefixIcon:
                            const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _startNavigation(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Start navigation',
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _startNavigation,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.navigation_outlined),
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            flex: 3,
            child: _currentPosition != null
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.signsense.ai',
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: AppTheme.ibmBlue,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_currentPosition != null)
                            Marker(
                              point: LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.ibmBlue,
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                : const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.ibmBlue),
                  ),
          ),

          // Navigation instruction panel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceDark,
            child: Column(
              children: [
                Text(
                  _currentInstruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isNavigating) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Step ${_currentStepIndex + 1} of ${_instructions.length}',
                    style: const TextStyle(
                      color: AppTheme.ibmCoolGray,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _repeatInstruction,
                          icon: const Icon(Icons.replay_outlined),
                          label: const Text('Repeat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.ibmBlue,
                            side:
                                const BorderSide(color: AppTheme.ibmBlue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _nextInstruction,
                          icon: const Icon(Icons.skip_next_outlined),
                          label: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
