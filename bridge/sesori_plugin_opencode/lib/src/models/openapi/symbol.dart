// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.966908Z

import 'package:meta/meta.dart';

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
      location: json["location"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "kind": kind,
      "location": location,
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
  final Map<String, dynamic> location;
}
