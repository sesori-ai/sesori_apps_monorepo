// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class ServerInfo {
  const ServerInfo({
    required this.version,
    required this.pid,
    required this.urls,
    required this.paths,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      version: json["version"] as String?,
      pid: (json["pid"] as num).toInt(),
      urls: (json["urls"] as List<dynamic>).cast<String>(),
      paths: ServerInfoPaths.fromJson(json["paths"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "version": version,
      "pid": pid,
      "urls": urls,
      "paths": paths.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ServerInfo copyWith({
    String? version,
    int? pid,
    List<String>? urls,
    ServerInfoPaths? paths,
  }) {
    return ServerInfo(
      version: version ?? this.version,
      pid: pid ?? this.pid,
      urls: urls ?? this.urls,
      paths: paths ?? this.paths,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerInfo &&
          other.version == version &&
          other.pid == pid &&
          const DeepCollectionEquality().equals(other.urls, urls) &&
          other.paths == paths);

  @override
  int get hashCode => Object.hash(version, pid, const DeepCollectionEquality().hash(urls), paths);

  final String? version;
  final int pid;
  final List<String> urls;
  final ServerInfoPaths paths;
}

@immutable
class ServerInfoPaths {
  const ServerInfoPaths({
    required this.tmp,
  });

  factory ServerInfoPaths.fromJson(Map<String, dynamic> json) {
    return ServerInfoPaths(
      tmp: json["tmp"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "tmp": tmp,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ServerInfoPaths copyWith({
    String? tmp,
  }) {
    return ServerInfoPaths(
      tmp: tmp ?? this.tmp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerInfoPaths &&
          other.tmp == tmp);

  @override
  int get hashCode => tmp.hashCode;

  final String tmp;
}
