// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'range.dart';

@immutable
class Symbol {
  const Symbol({
    required this.name,
    required this.kind,
    required this.location,
  });

  factory Symbol.fromJson(Map<String, dynamic> json) {
    return Symbol(
      name: json["name"] as String,
      kind: (json["kind"] as num).toInt(),
      location: SymbolLocation.fromJson(json["location"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "kind": kind,
      "location": location.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Symbol &&
          other.name == name &&
          other.kind == kind &&
          other.location == location);

  @override
  int get hashCode => Object.hash(name, kind, location);

  final String name;
  final int kind;
  final SymbolLocation location;
}

@immutable
class SymbolLocation {
  const SymbolLocation({
    required this.uri,
    required this.range,
  });

  factory SymbolLocation.fromJson(Map<String, dynamic> json) {
    return SymbolLocation(
      uri: json["uri"] as String,
      range: Range.fromJson(json["range"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "uri": uri,
      "range": range.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SymbolLocation &&
          other.uri == uri &&
          other.range == range);

  @override
  int get hashCode => Object.hash(uri, range);

  final String uri;
  final Range range;
}
