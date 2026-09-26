// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_cleanup_rejection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionCleanupRejection _$SessionCleanupRejectionFromJson(Map json) =>
    _SessionCleanupRejection(
      issues: (json['issues'] as List<dynamic>)
          .map(
            (e) => CleanupIssue.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

Map<String, dynamic> _$SessionCleanupRejectionToJson(
  _SessionCleanupRejection instance,
) => <String, dynamic>{
  'issues': instance.issues.map((e) => e.toJson()).toList(),
};

CleanupIssueUnstagedChanges _$CleanupIssueUnstagedChangesFromJson(Map json) =>
    CleanupIssueUnstagedChanges($type: json['type'] as String?);

Map<String, dynamic> _$CleanupIssueUnstagedChangesToJson(
  CleanupIssueUnstagedChanges instance,
) => <String, dynamic>{'type': instance.$type};

CleanupIssueSharedWorktree _$CleanupIssueSharedWorktreeFromJson(Map json) =>
    CleanupIssueSharedWorktree($type: json['type'] as String?);

Map<String, dynamic> _$CleanupIssueSharedWorktreeToJson(
  CleanupIssueSharedWorktree instance,
) => <String, dynamic>{'type': instance.$type};
