import "dart:math" as math;
import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";

/// Cuts a recorder's byte chunks into frames the realtime endpoint accepts: whole
/// PCM16 samples, up to [realtimeVoiceMaxFrameBytes] each.
///
/// Chunks arrive however the platform delivers them. On Linux they are reads from
/// the `parecord` pipe, which can end in the middle of a sample. Dropping that byte
/// would shift every later sample and turn the audio into noise, so it is held for
/// the next chunk.
final class PcmFrameBuilder() {
  int? _heldByte;

  List<Uint8List> add({required Uint8List chunk}) {
    if (chunk.isEmpty) return const [];

    final heldByte = _heldByte;
    final available = heldByte == null ? chunk.length : chunk.length + 1;
    final alignedLength = available - available % 2;
    _heldByte = available.isOdd ? chunk.last : null;
    if (alignedLength == 0) return const [];

    final aligned = heldByte == null
        ? Uint8List.sublistView(chunk, 0, alignedLength)
        : (Uint8List(alignedLength)
            ..[0] = heldByte
            ..setRange(1, alignedLength, chunk));
    return [
      for (var start = 0; start < alignedLength; start += realtimeVoiceMaxFrameBytes)
        Uint8List.sublistView(aligned, start, math.min(start + realtimeVoiceMaxFrameBytes, alignedLength)),
    ];
  }
}
