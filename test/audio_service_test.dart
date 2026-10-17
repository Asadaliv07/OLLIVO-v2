import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/services/audio_service.dart';

void main() {
  group('AudioService Unit and Speech Tests', () {
    test('Validates audio file format extensions correctly', () {
      final audioService = AudioService();

      expect(audioService.isSupportedAudioFormat('recording.wav'), isTrue);
      expect(audioService.isSupportedAudioFormat('memo.mp3'), isTrue);
      expect(audioService.isSupportedAudioFormat('audio.m4a'), isTrue);
      expect(audioService.isSupportedAudioFormat('speech.flac'), isTrue);
      expect(audioService.isSupportedAudioFormat('track.ogg'), isTrue);

      expect(audioService.isSupportedAudioFormat('document.pdf'), isFalse);
      expect(audioService.isSupportedAudioFormat('script.py'), isFalse);
      expect(audioService.isSupportedAudioFormat('archive.zip'), isFalse);
    });

    test('Throws ArgumentError when transcribing unsupported file format', () async {
      final audioService = AudioService();
      expect(
        () => audioService.transcribeAudio('/tmp/notes.txt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Transcribes supported audio file with successful mock response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/ai/audio/transcribe') {
          return http.Response(
            jsonEncode({
              'text': 'Welcome to Ollivo local AI workspace.',
              'language': 'en',
              'confidence': 0.98,
              'segments': [
                {'start': 0.0, 'end': 2.5, 'text': 'Welcome to Ollivo local AI workspace.'}
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final audioService = AudioService(client: mockClient);
      audioService.configure(
        stt: SttEngine.fasterWhisper,
        endpoint: 'http://127.0.0.1:8765',
      );

      final result = await audioService.transcribeAudio('voice_prompt.wav');
      expect(result.text, equals('Welcome to Ollivo local AI workspace.'));
      expect(result.confidence, closeTo(0.98, 0.01));
      expect(result.language, equals('en'));
    });

    test('Synthesizes text to speech using mock TTS backend', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/ai/audio/synthesize') {
          final dummyWavBytes = List<int>.filled(1024, 0);
          return http.Response.bytes(dummyWavBytes, 200);
        }
        return http.Response('Not Found', 404);
      });

      final audioService = AudioService(client: mockClient);
      audioService.configure(tts: TtsEngine.kokoro82m);

      final result = await audioService.synthesizeSpeech('Hello from Kokoro TTS engine');
      expect(result.format, equals('wav'));
      expect(result.byteLength, equals(1024));
      expect(result.sampleRate, equals(24000));
    });

    test('Manages playback state and text tracking correctly', () {
      final audioService = AudioService();

      expect(audioService.isPlaying, isFalse);
      expect(audioService.currentlyPlayingText, isNull);

      audioService.startPlayback('Reading system status...');
      expect(audioService.isPlaying, isTrue);
      expect(audioService.currentlyPlayingText, equals('Reading system status...'));

      audioService.stopPlayback();
      expect(audioService.isPlaying, isFalse);
      expect(audioService.currentlyPlayingText, isNull);
    });
  });
}
