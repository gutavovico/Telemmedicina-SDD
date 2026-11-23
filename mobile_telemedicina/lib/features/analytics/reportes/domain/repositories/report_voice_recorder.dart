import 'dart:typed_data';

class ReportAudio {
  final Uint8List bytes;
  final String filename, mimeType;
  const ReportAudio(this.bytes, {this.filename = 'dictado.wav',
    this.mimeType = 'audio/wav'});
}

abstract class ReportVoiceRecorder {
  Future<void> start({required void Function(Object error) onFailure});
  Future<ReportAudio> stop();
  Future<void> cancel();
  Future<void> dispose();
}
