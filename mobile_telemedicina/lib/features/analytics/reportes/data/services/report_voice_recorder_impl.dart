import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../domain/repositories/report_voice_recorder.dart';

/// Graba PCM16 en memoria y lo empaqueta como RIFF/WAVE real. No crea archivos.
class ReportVoiceRecorderImpl implements ReportVoiceRecorder {
  static const maxAudioBytes = 5 * 1024 * 1024;
  static const sampleRate = 16000;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  final List<Uint8List> _chunks = [];
  int _length = 0;
  bool _recording = false;
  bool _disposed = false;
  Object? _failure;

  @override
  Future<void> start({required void Function(Object error) onFailure}) async {
    if (_disposed || _recording) throw StateError('El micrófono no está disponible.');
    _chunks.clear(); _length = 0; _failure = null;
    if (!await _recorder.hasPermission()) {
      throw StateError('Autoriza el micrófono o escribe la solicitud manualmente.');
    }
    if (!await _recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
      throw StateError('Este dispositivo no admite dictado WAV. Usa el texto manual.');
    }
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits, sampleRate: sampleRate, numChannels: 1));
    _recording = true;
    _subscription = stream.listen((chunk) {
      if (!_recording) return;
      if (_length + chunk.length + 44 > maxAudioBytes) {
        _failure = StateError('El audio supera 5 MiB. Graba una solicitud más breve.');
        onFailure(_failure!);
        return;
      }
      _chunks.add(chunk);
      _length += chunk.length;
    }, onError: (Object error) {
      _failure = error;
      onFailure(StateError('Se interrumpió la grabación. Usa el texto manual.'));
    });
  }

  @override
  Future<ReportAudio> stop() async {
    if (!_recording) throw StateError('No hay una grabación activa.');
    await _recorder.stop();
    _recording = false;
    await _subscription?.cancel();
    _subscription = null;
    if (_failure != null) throw StateError('La grabación falló. Reintenta.');
    if (_length == 0 || _length.isOdd || _length + 44 > maxAudioBytes) {
      throw StateError('El audio está vacío o no es válido. Reintenta.');
    }
    final bytes = Uint8List(_length + 44);
    final header = ByteData.sublistView(bytes);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) { bytes[offset + i] = value.codeUnitAt(i); }
    }
    ascii(0, 'RIFF');
    header.setUint32(4, _length + 36, Endian.little);
    ascii(8, 'WAVE'); ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, _length, Endian.little);
    var offset = 44;
    for (final chunk in _chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _chunks.clear(); _length = 0;
    return ReportAudio(bytes);
  }

  @override
  Future<void> cancel() async {
    _recording = false;
    await _subscription?.cancel();
    _subscription = null;
    _chunks.clear(); _length = 0;
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
    await _recorder.dispose();
  }
}
