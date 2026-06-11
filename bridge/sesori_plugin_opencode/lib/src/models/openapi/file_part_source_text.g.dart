// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class FilePartSourceText {
  const FilePartSourceText({
    this.value = '',
    this.start = 0,
    this.end = 0,
  });

  factory FilePartSourceText.fromJson(Map<String, dynamic> json) {
    return FilePartSourceText(
      value: (json["value"] ?? '') as String,
      start: ((json["start"] ?? 0) as num).toDouble(),
      end: ((json["end"] ?? 0) as num).toDouble(),
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
