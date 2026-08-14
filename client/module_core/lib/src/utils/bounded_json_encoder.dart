import "dart:async";
import "dart:convert";
import "dart:typed_data";

final class BoundedBase64Value({required final Uint8List bytes});

final class BoundedJsonEncoder({
  required final int chunkSize,
  required final Future<void> Function() yieldTurn,
}) {
  static const int defaultChunkSize = 64 * 1024;

  static Future<void> eventLoopTurn() => Future<void>.delayed(Duration.zero);

  Future<Uint8List> convert<T extends Object?>({required T value}) async {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, "chunkSize", "must be positive");
    }
    final output = _BoundedByteBuilder(chunkSize: chunkSize, yieldTurn: yieldTurn);
    Future<void> writeString(String string) async {
      await output.addByte(0x22);
      var start = 0;
      while (start < string.length) {
        var end = (start + chunkSize).clamp(0, string.length);
        if (end < string.length &&
            _isHighSurrogate(string.codeUnitAt(end - 1)) &&
            _isLowSurrogate(string.codeUnitAt(end))) {
          end++;
        }
        final encoded = _utf8Bytes(jsonEncode(string.substring(start, end)));
        await output.add(Uint8List.sublistView(encoded, 1, encoded.length - 1));
        start = end;
      }
      await output.addByte(0x22);
    }

    Future<void> writeBase64(Uint8List bytes) async {
      await output.addByte(0x22);
      final sourceChunkSize = chunkSize < 3 ? 3 : chunkSize - chunkSize % 3;
      var start = 0;
      while (start < bytes.length) {
        final end = (start + sourceChunkSize).clamp(0, bytes.length);
        final sourceView = Uint8List.sublistView(bytes, start, end);
        await output.add(_utf8Bytes(base64Encode(sourceView)));
        start = end;
      }
      await output.addByte(0x22);
    }

    // JSON is intentionally heterogeneous at this serialization boundary.
    // ignore: no_slop_linter/prefer_specific_type
    late final Future<void> Function(Object? current) writeValue;
    // ignore: no_slop_linter/prefer_specific_type
    writeValue = (Object? current) async {
      if (current == null || current is bool || current is num) {
        await output.add(_utf8Bytes(jsonEncode(current)));
        return;
      }
      if (current is String) {
        await writeString(current);
        return;
      }
      if (current is BoundedBase64Value) {
        await writeBase64(current.bytes);
        return;
      }
      // ignore: no_slop_linter/prefer_specific_type
      if (current is List<Object?>) {
        await output.addByte(0x5B);
        for (var index = 0; index < current.length; index++) {
          if (index != 0) await output.addByte(0x2C);
          await writeValue(current[index]);
        }
        await output.addByte(0x5D);
        return;
      }
      // ignore: no_slop_linter/prefer_specific_type
      if (current is Map<String, Object?>) {
        await output.addByte(0x7B);
        var first = true;
        for (final entry in current.entries) {
          if (!first) await output.addByte(0x2C);
          first = false;
          await writeString(entry.key);
          await output.addByte(0x3A);
          await writeValue(entry.value);
        }
        await output.addByte(0x7D);
        return;
      }
      throw JsonUnsupportedObjectError(current);
    };

    await writeValue(value);
    return output.takeBytes();
  }

  Future<String> convertToString<T>({required T value}) async {
    return utf8.decode(await convert(value: value));
  }

  bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

  bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

  Uint8List _utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));
}

final class _BoundedByteBuilder({
  required final int chunkSize,
  required final Future<void> Function() yieldTurn,
}) {
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  int _bytesInChunk = 0;

  Future<void> addByte(int byte) async {
    await add(Uint8List.fromList([byte]));
  }

  Future<void> add(Uint8List bytes) async {
    var start = 0;
    while (start < bytes.length) {
      if (_bytesInChunk == chunkSize) {
        _bytesInChunk = 0;
        await yieldTurn();
      }
      final available = chunkSize - _bytesInChunk;
      final end = (start + available).clamp(0, bytes.length);
      _bytes.add(Uint8List.sublistView(bytes, start, end));
      _bytesInChunk += end - start;
      start = end;
    }
  }

  Uint8List takeBytes() => _bytes.takeBytes();
}
