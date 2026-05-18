import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Voice-to-text for Home (English). On Android uses the system speech dialog
/// (Google) via a platform channel — reliable when [speech_to_text] streaming fails.
class VoiceInputController {
  static const MethodChannel _androidChannel =
      MethodChannel('com.bur.app/voice_intent');

  final stt.SpeechToText _speech = stt.SpeechToText();

  String? _englishLocaleId;
  bool _initialized = false;
  int _listenGeneration = 0;

  bool get isAvailable => _speech.isAvailable;
  bool get isListening => _speech.isListening;
  String get lastRecognizedWords => _speech.lastRecognizedWords;

  static bool get isPlatformSupported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  static bool get usesAndroidSpeechDialog =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String messageForErrorCode(String code) {
    switch (code) {
      case 'error_permission':
        return 'Allow microphone access in Settings, then try Voice Input again.';
      case 'error_no_match':
      case 'doneNoResult':
      case 'no_match':
        return 'No speech detected. Speak clearly in English and try again.';
      case 'error_speech_timeout':
        return 'No speech heard in time. Try Voice Input again.';
      case 'error_network':
      case 'error_network_timeout':
        return 'Voice input needs internet. Check your connection and try again.';
      case 'error_busy':
      case 'busy':
        return 'Speech service is busy. Wait a moment and try again.';
      case 'error_server':
      case 'error_server_disconnected':
        return 'Google speech could not connect. Update the Google app and check internet.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return 'Install English: Settings → Google → Voice → Offline speech → English.';
      case 'unavailable':
        return 'Speech recognition is not available. Install or update the Google app.';
      case 'cancelled':
        return 'Voice input was cancelled.';
      default:
        return 'Voice input failed. Update Google app or type your answer in English.';
    }
  }

  /// Android: opens the system Google speech UI and returns recognized English text.
  Future<String?> recognizeWithSystemDialog() async {
    if (!usesAndroidSpeechDialog) {
      return null;
    }
    try {
      final String? text =
          await _androidChannel.invokeMethod<String>('recognizeEnglish');
      final String trimmed = text?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') {
        return null;
      }
      throw VoiceInputException(
        messageForErrorCode(e.code),
        code: e.code,
      );
    }
  }

  Future<bool> _initializeStreamingEngine() async {
    if (_initialized && _speech.isAvailable) {
      return true;
    }

    final bool ready = await _speech.initialize(
      debugLogging: kDebugMode,
      options: <stt.SpeechConfigOption>[
        stt.SpeechToText.androidNoBluetooth,
      ],
    );

    if (!ready) {
      _initialized = false;
      return false;
    }

    await _cacheEnglishLocaleIfAvailable();
    _initialized = true;
    return true;
  }

  Future<void> _cacheEnglishLocaleIfAvailable() async {
    _englishLocaleId = null;
    try {
      final List<stt.LocaleName> locales = await _speech.locales();
      for (final stt.LocaleName locale in locales) {
        final String id = locale.localeId.toLowerCase().replaceAll('_', '-');
        if (id == 'en-us') {
          _englishLocaleId = locale.localeId;
          return;
        }
      }
      for (final stt.LocaleName locale in locales) {
        final String id = locale.localeId.toLowerCase().replaceAll('_', '-');
        if (id == 'en' || id.startsWith('en-')) {
          _englishLocaleId = locale.localeId;
          return;
        }
      }
    } catch (e, st) {
      debugPrint('VoiceInputController locales: $e\n$st');
    }
  }

  Future<void> _releaseSession() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
    try {
      await _speech.cancel();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  /// iOS: in-app streaming listen. Android should use [recognizeWithSystemDialog].
  Future<bool> startListening({
    required void Function(String text) onText,
    void Function(double level)? onSoundLevel,
    void Function(String message)? onError,
    void Function(bool listening)? onListeningChanged,
  }) async {
    if (usesAndroidSpeechDialog) {
      onError?.call('Use recognizeWithSystemDialog on Android.');
      return false;
    }

    if (!await _initializeStreamingEngine()) {
      onError?.call(
        'Speech recognition is unavailable. Allow microphone access and try again.',
      );
      return false;
    }

    final int generation = ++_listenGeneration;

    _speech.errorListener = (SpeechRecognitionError err) {
      if (generation != _listenGeneration) return;
      onListeningChanged?.call(false);
      onError?.call(messageForErrorCode(err.errorMsg));
    };

    _speech.statusListener = (String status) {
      if (generation != _listenGeneration) return;
      if (status == stt.SpeechToText.listeningStatus) {
        onListeningChanged?.call(true);
        return;
      }
      if (status == stt.SpeechToText.notListeningStatus) {
        return;
      }
      if (status == 'doneNoResult') {
        onListeningChanged?.call(false);
        onError?.call(messageForErrorCode('doneNoResult'));
        return;
      }
      if (status == stt.SpeechToText.doneStatus) {
        onListeningChanged?.call(false);
        final String words = _speech.lastRecognizedWords.trim();
        if (words.isNotEmpty) {
          onText(words);
        }
      }
    };

    await _releaseSession();

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (generation != _listenGeneration) return;
          final String words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            onText(words);
          }
        },
        onSoundLevelChange: onSoundLevel,
        localeId: _englishLocaleId,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 12),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          onDevice: false,
        ),
      );
    } catch (e, st) {
      debugPrint('VoiceInput iOS listen: $e\n$st');
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    return generation == _listenGeneration && _speech.isListening;
  }

  Future<void> stop() async {
    _listenGeneration++;
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
  }

  void dispose() {
    _listenGeneration++;
    _speech.errorListener = null;
    _speech.statusListener = null;
    if (_speech.isListening) {
      unawaited(_speech.stop());
    }
  }
}

class VoiceInputException implements Exception {
  VoiceInputException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}
