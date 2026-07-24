import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoiceState { idle, speaking, listening }

class VoiceProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  VoiceState _state = VoiceState.idle;
  String _lastSpokenText = '';
  String _recognizedText = '';
  bool _isListening = false;
  bool _isSpeaking = false;

  VoiceState get state => _state;
  String get lastSpokenText => _lastSpokenText;
  String get recognizedText => _recognizedText;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  VoiceProvider() {
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      _state = VoiceState.speaking;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _state = VoiceState.idle;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _state = VoiceState.idle;
      notifyListeners();
    });
  }

  /// Speak a text string aloud — primary accessibility output.
  Future<void> speak(String text, {bool interrupt = true}) async {
    if (interrupt && _isSpeaking) {
      await _tts.stop();
    }
    _lastSpokenText = text;
    await _tts.speak(text);
    notifyListeners();
  }

  /// Speak with priority (interrupt anything currently playing).
  Future<void> speakPriority(String text) async {
    await _tts.stop();
    _lastSpokenText = text;
    await _tts.speak(text);
    notifyListeners();
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    _state = VoiceState.idle;
    notifyListeners();
  }

  /// Update TTS engine settings at runtime (from SettingsScreen).
  Future<void> updateSettings({
    double? rate,
    double? volume,
    double? pitch,
    String? language,
  }) async {
    if (rate != null) await _tts.setSpeechRate(rate);
    if (volume != null) await _tts.setVolume(volume);
    if (pitch != null) await _tts.setPitch(pitch);
    if (language != null) await _tts.setLanguage(language);
  }

  /// Start voice command recognition.
  Future<void> startListening({Function(String)? onResult}) async {
    bool available = await _speechToText.initialize(
      onError: (error) {
        _isListening = false;
        _state = VoiceState.idle;
        notifyListeners();
      },
    );

    if (available) {
      _isListening = true;
      _state = VoiceState.listening;
      notifyListeners();

      _speechToText.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords.toLowerCase();
          notifyListeners();
          if (result.finalResult && onResult != null) {
            onResult(_recognizedText);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN',
      );
    }
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    _isListening = false;
    _state = VoiceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    _speechToText.stop();
    super.dispose();
  }
}
