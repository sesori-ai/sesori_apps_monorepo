// GENERATED FILE - DO NOT EDIT BY HAND

import 'prompt_source.dart';

class PromptReferenceAttachment {
  const PromptReferenceAttachment({
    required this.name,
    required this.kind,
    this.uri,
    this.repository,
    this.branch,
    this.target,
    this.targetUri,
    this.problem,
    this.source,
  });

  factory PromptReferenceAttachment.fromJson(Map<String, dynamic> json) {
    return PromptReferenceAttachment(
      name: json["name"] as String,
      kind: json["kind"] as String,
      uri: json["uri"] as String?,
      repository: json["repository"] as String?,
      branch: json["branch"] as String?,
      target: json["target"] as String?,
      targetUri: json["targetUri"] as String?,
      problem: json["problem"] as String?,
      source: json["source"] == null ? null : PromptSource.fromJson(json["source"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "kind": kind,
      "uri": uri,
      "repository": repository,
      "branch": branch,
      "target": target,
      "targetUri": targetUri,
      "problem": problem,
      "source": source?.toJson(),
    };
  }

  final String name;
  final String kind;
  final String? uri;
  final String? repository;
  final String? branch;
  final String? target;
  final String? targetUri;
  final String? problem;
  final PromptSource? source;
}
