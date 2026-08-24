import "dart:convert";
import "dart:math";

// ignore: no_slop_linter/prefer_specific_type, centralized decoded JSON boundary
Map<String, dynamic> jsonCastMap(dynamic value) {
  if (value is Map) return value.cast();
  throw FormatException("Invalid JSON Object (not a Map)", value);
}

// ignore: no_slop_linter/prefer_specific_type, JSON decoding
Map<String, dynamic> jsonDecodeMap(String source) {
  return jsonCastMap(jsonDecode(source));
}

// ignore: no_slop_linter/prefer_specific_type, decoded JSON boundary
Map<String, dynamic>? asStringKeyedMap(Object? value) => value is Map ? value.cast<String, dynamic>() : null;

// ignore: no_slop_linter/prefer_specific_type, decoded JSON boundary
String? nonEmptyString(Object? value) => value is String && value.isNotEmpty ? value : null;

// ignore: no_slop_linter/prefer_specific_type, JSON decoding
List<Map<String, dynamic>> jsonDecodeListMap(String source) {
  final result = jsonDecode(source);

  if (result is List) {
    return result.cast();
  } else {
    throw FormatException(
      "Invalid JSON Array (not a List) in jsonDecodeListMap: $source",
    );
  }
}

extension StringExtensions on String {
  /// Trimmed text, or `null` when nothing but whitespace remains.
  String? normalize() {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> chunked({required int chunkSize}) {
    final chunks = <String>[];

    var chunkIndex = 0;
    while (true) {
      final start = chunkIndex * chunkSize;
      final end = min((chunkIndex + 1) * chunkSize, length);

      if (start >= length) {
        break;
      }
      chunks.add(substring(start, end));
      chunkIndex++;
    }

    return chunks;
  }
}
