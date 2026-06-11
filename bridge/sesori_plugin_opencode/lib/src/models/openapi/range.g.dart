// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class Range {
  const Range({
    required this.start,
    required this.end,
  });

  factory Range.fromJson(Map<String, dynamic> json) {
    return Range(
      start: RangeStart.fromJson((json["start"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
      end: RangeEnd.fromJson((json["end"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start.toJson(),
      "end": end.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Range copyWith({
    RangeStart? start,
    RangeEnd? end,
  }) {
    return Range(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Range &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  final RangeStart start;
  final RangeEnd end;
}

@immutable
class RangeStart {
  const RangeStart({
    this.line = 0,
    this.character = 0,
  });

  factory RangeStart.fromJson(Map<String, dynamic> json) {
    return RangeStart(
      line: ((json["line"] ?? 0) as num).toInt(),
      character: ((json["character"] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "line": line,
      "character": character,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  RangeStart copyWith({
    int? line,
    int? character,
  }) {
    return RangeStart(
      line: line ?? this.line,
      character: character ?? this.character,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RangeStart &&
          other.line == line &&
          other.character == character);

  @override
  int get hashCode => Object.hash(line, character);

  final int line;
  final int character;
}

@immutable
class RangeEnd {
  const RangeEnd({
    this.line = 0,
    this.character = 0,
  });

  factory RangeEnd.fromJson(Map<String, dynamic> json) {
    return RangeEnd(
      line: ((json["line"] ?? 0) as num).toInt(),
      character: ((json["character"] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "line": line,
      "character": character,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  RangeEnd copyWith({
    int? line,
    int? character,
  }) {
    return RangeEnd(
      line: line ?? this.line,
      character: character ?? this.character,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RangeEnd &&
          other.line == line &&
          other.character == character);

  @override
  int get hashCode => Object.hash(line, character);

  final int line;
  final int character;
}
