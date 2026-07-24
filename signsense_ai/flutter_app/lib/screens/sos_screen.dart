import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/voice_provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  Position? _currentPosition;
  bool _isLocating = false;
  bool _alertSent = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceProvider>().speakPriority(
        'Emergency SOS screen. Tap SOS button to alert your emergency contact.',
      );
      _fetchLocation();
    });
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _statusMessage = 'Location services disabled.';
          _isLocating = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _statusMessage = 'Location permission denied.';
            _isLocating = false;
          });
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _statusMessage =
            'Location found: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
            '${_currentPosition!.longitude.toStringAsFixed(4)}';
        _isLocating = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to get location.';
        _isLocating = false;
      });
    }
  }

  Future<void> _sendSOS() async {
    final appProvider = context.read<AppProvider>();
    final voice = context.read<VoiceProvider>();

    voice.speakPriority('Sending emergency SOS alert!');

    // Re-fetch fresh location
    await _fetchLocation();

    final contactNumber = appProvider.emergencyContact;
    final lat = _currentPosition?.latitude ?? 0.0;
    final lng = _currentPosition?.longitude ?? 0.0;
    final mapsLink = 'https://maps.google.com/?q=$lat,$lng';

    final message =
        'EMERGENCY SOS from SignSense AI user!\n'
        'I need immediate help.\n'
        'My location: $mapsLink\n'
        'Lat: $lat, Lng: $lng';

    // Try to send SMS
    if (contactNumber.isNotEmpty) {
      final smsUri = Uri.parse(
        'sms:$contactNumber?body=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        setState(() => _alertSent = true);
      }
    }

    // Share location via system share sheet
    // share_plus v10: Share.share() returns ShareResult; subject param is
    // not supported on Android (only on iOS mail). Use Share.share(text).
    await Share.share(message);

    setState(() => _alertSent = true);
    voice.speakPriority('SOS alert sent. Help is on the way. Stay calm.');
  }

  Future<void> _callEmergency() async {
    const emergencyNumber = 'tel:112';
    final uri = Uri.parse(emergencyNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
    context.read<VoiceProvider>().speak('Calling emergency services. 1 1 2.');
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.ibmRed,
        title: const Text('Emergency SOS'),
      ),
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Warning header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.ibmRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.ibmRed),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: AppTheme.ibmRed, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Emergency SOS',
                      style: TextStyle(
                        color: AppTheme.ibmRed,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This will alert your emergency contact\nand share your live location.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Location status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.ibmGreen,
                            ),
                          )
                        : Icon(
                            _currentPosition != null
                                ? Icons.location_on_outlined
                                : Icons.location_off_outlined,
                            color: _currentPosition != null
                                ? AppTheme.ibmGreen
                                : AppTheme.ibmRed,
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isLocating
                            ? 'Getting your location...'
                            : _statusMessage.isNotEmpty
                                ? _statusMessage
                                : 'Location not available',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (!_isLocating)
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.ibmBlue),
                        onPressed: _fetchLocation,
                        tooltip: 'Refresh location',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Emergency contact display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.contact_phone_outlined,
                        color: AppTheme.ibmBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        appProvider.emergencyContact.isNotEmpty
                            ? 'Contact: ${appProvider.emergencyContact}'
                            : 'No emergency contact set. Go to Settings.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // SOS sent confirmation
              if (_alertSent)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.ibmGreen),
                      SizedBox(width: 8),
                      Text(
                        'SOS Sent! Help is coming.',
                        style: TextStyle(
                          color: AppTheme.ibmGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Big SOS button
              Semantics(
                label: 'Send SOS emergency alert',
                button: true,
                child: GestureDetector(
                  onTap: _sendSOS,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.ibmRed,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.ibmRed.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sos_outlined, size: 60, color: Colors.white),
                        SizedBox(height: 8),
                        Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Call 112 button
              Semantics(
                label: 'Call emergency services 112',
                button: true,
                child: OutlinedButton.icon(
                  onPressed: _callEmergency,
                  icon: const Icon(Icons.phone_outlined, color: AppTheme.ibmRed),
                  label: const Text(
                    'Call 112 — Emergency Services',
                    style: TextStyle(color: AppTheme.ibmRed),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.ibmRed),
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
