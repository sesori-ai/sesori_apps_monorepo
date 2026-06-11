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
      start: RangeStart.fromJson(json["start"] as Map<String, dynamic>),
      end: RangeEnd.fromJson(json["end"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start.toJson(),
      "end": end.toJson(),
    };
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
    required this.line,
    required this.character,
  });

  factory RangeStart.fromJson(Map<String, dynamic> json) {
    return RangeStart(
      line: (json["line"] as num).toInt(),
      character: (json["character"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "line": line,
      "character": character,
    };
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
    required this.line,
    required this.character,
  });

  factory RangeEnd.fromJson(Map<String, dynamic> json) {
    return RangeEnd(
      line: (json["line"] as num).toInt(),
      character: (json["character"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "line": line,
      "character": character,
    };
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
