import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_provider.dart';
import '../utils/app_theme.dart';

/// Floating voice command button — available on Home and Mode screens.
///
/// Phase F: Extended voice commands to include "blind mode" and "deaf mode"
/// so users can jump to Mode 1/Mode 2 without tapping the buttons.
class VoiceFAB extends StatelessWidget {
  const VoiceFAB({super.key});

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceProvider>();

    return Semantics(
      label: voice.isListening
          ? 'Stop voice command'
          : 'Tap for voice command',
      button: true,
      child: FloatingActionButton.extended(
        onPressed: () {
          if (voice.isListening) {
            voice.stopListening();
          } else {
            voice.speak('Listening. Say a command.');
            voice.startListening(onResult: (text) {
              _handleVoiceCommand(context, text);
            });
          }
        },
        backgroundColor:
            voice.isListening ? AppTheme.ibmRed : AppTheme.ibmBlue,
        icon: Icon(
          voice.isListening
              ? Icons.mic_outlined
              : Icons.mic_none_outlined,
          color: Colors.white,
        ),
        label: Text(
          voice.isListening ? 'Listening...' : 'Voice Command',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _handleVoiceCommand(BuildContext context, String command) {
    final voice = context.read<VoiceProvider>();
    final lower = command.toLowerCase();

    // ── Mode shortcuts ────────────────────────────────────────────────────
    if (lower.contains('blind') || lower.contains('mode one') ||
        lower.contains('mode 1')) {
      voice.speak('Opening Blind AI Voice Assistant.');
      Navigator.pushNamed(context, '/blind-mode');
    } else if (lower.contains('deaf') || lower.contains('sign') ||
        lower.contains('mode two') || lower.contains('mode 2')) {
      voice.speak('Opening Deaf and Mute AI Assistant.');
      Navigator.pushNamed(context, '/deaf-mode');

      // ── Individual feature shortcuts ───────────────────────────────────
    } else if (lower.contains('object') || lower.contains('detect')) {
      voice.speak('Opening object detection.');
      Navigator.pushNamed(context, '/camera');
    } else if (lower.contains('navigate') || lower.contains('navigation') ||
        lower.contains('direction')) {
      voice.speak('Opening navigation.');
      Navigator.pushNamed(context, '/navigation');
    } else if (lower.contains('text') ||
        lower.contains('read') ||
        lower.contains('ocr')) {
      voice.speak('Opening text reader.');
      Navigator.pushNamed(context, '/ocr');
    } else if (lower.contains('currency') || lower.contains('money') ||
        lower.contains('rupee')) {
      voice.speak('Opening currency detection.');
      Navigator.pushNamed(context, '/currency');
    } else if (lower.contains('scene') || lower.contains('describe')) {
      voice.speak('Opening scene description.');
      Navigator.pushNamed(context, '/scene-description');
    } else if (lower.contains('sos') ||
        lower.contains('emergency') ||
        lower.contains('help')) {
      voice.speakPriority('Opening emergency SOS.');
      Navigator.pushNamed(context, '/sos');
    } else if (lower.contains('setting')) {
      voice.speak('Opening settings.');
      Navigator.pushNamed(context, '/settings');
    } else if (lower.contains('history')) {
      voice.speak('Opening history.');
      Navigator.pushNamed(context, '/history');
    } else {
      voice.speak(
        'Command not recognized. '
        'Say: blind mode, deaf mode, detect objects, navigate, '
        'read text, currency, describe scene, SOS, or settings.',
      );
    }
  }
}
