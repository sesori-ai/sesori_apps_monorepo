// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';

@immutable
class FilePartSourceText {
  const FilePartSourceText({
    required this.value,
    required this.start,
    required this.end,
  });

  factory FilePartSourceText.fromJson(Map<String, dynamic> json) {
    return FilePartSourceText(
      value: json["value"] as String,
      start: (json["start"] as num).toDouble(),
      end: (json["end"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "value": value,
      "start": start,
      "end": end,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FilePartSourceText copyWith({
    String? value,
    double? start,
    double? end,
  }) {
    return FilePartSourceText(
      value: value ?? this.value,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilePartSourceText &&
          other.value == value &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(value, start, end);

  final String value;
  final double start;
  final double end;
}
