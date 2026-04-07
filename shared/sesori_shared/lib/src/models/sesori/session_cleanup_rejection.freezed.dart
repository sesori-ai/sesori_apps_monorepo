// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_cleanup_rejection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionCleanupRejection {

 List<CleanupIssue> get issues;
/// Create a copy of SessionCleanupRejection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCleanupRejectionCopyWith<SessionCleanupRejection> get copyWith => _$SessionCleanupRejectionCopyWithImpl<SessionCleanupRejection>(this as SessionCleanupRejection, _$identity);

  /// Serializes this SessionCleanupRejection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionCleanupRejection&&const DeepCollectionEquality().equals(other.issues, issues));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(issues));

@override
String toString() {
  return 'SessionCleanupRejection(issues: $issues)';
}


}

/// @nodoc
abstract mixin class $SessionCleanupRejectionCopyWith<$Res>  {
  factory $SessionCleanupRejectionCopyWith(SessionCleanupRejection value, $Res Function(SessionCleanupRejection) _then) = _$SessionCleanupRejectionCopyWithImpl;
@useResult
$Res call({
 List<CleanupIssue> issues
});




}
/// @nodoc
class _$SessionCleanupRejectionCopyWithImpl<$Res>
    implements $SessionCleanupRejectionCopyWith<$Res> {
  _$SessionCleanupRejectionCopyWithImpl(this._self, this._then);

  final SessionCleanupRejection _self;
  final $Res Function(SessionCleanupRejection) _then;

/// Create a copy of SessionCleanupRejection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? issues = null,}) {
  return _then(_self.copyWith(
issues: null == issues ? _self.issues : issues // ignore: cast_nullable_to_non_nullable
as List<CleanupIssue>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionCleanupRejection implements SessionCleanupRejection {
  const _SessionCleanupRejection({required final  List<CleanupIssue> issues}): _issues = issues;
  factory _SessionCleanupRejection.fromJson(Map<String, dynamic> json) => _$SessionCleanupRejectionFromJson(json);

 final  List<CleanupIssue> _issues;
@override List<CleanupIssue> get issues {
  if (_issues is EqualUnmodifiableListView) return _issues;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_issues);
}


/// Create a copy of SessionCleanupRejection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCleanupRejectionCopyWith<_SessionCleanupRejection> get copyWith => __$SessionCleanupRejectionCopyWithImpl<_SessionCleanupRejection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionCleanupRejectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionCleanupRejection&&const DeepCollectionEquality().equals(other._issues, _issues));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_issues));

@override
String toString() {
  return 'SessionCleanupRejection(issues: $issues)';
}


}

/// @nodoc
abstract mixin class _$SessionCleanupRejectionCopyWith<$Res> implements $SessionCleanupRejectionCopyWith<$Res> {
  factory _$SessionCleanupRejectionCopyWith(_SessionCleanupRejection value, $Res Function(_SessionCleanupRejection) _then) = __$SessionCleanupRejectionCopyWithImpl;
@override @useResult
$Res call({
 List<CleanupIssue> issues
});




}
/// @nodoc
class __$SessionCleanupRejectionCopyWithImpl<$Res>
    implements _$SessionCleanupRejectionCopyWith<$Res> {
  __$SessionCleanupRejectionCopyWithImpl(this._self, this._then);

  final _SessionCleanupRejection _self;
  final $Res Function(_SessionCleanupRejection) _then;

/// Create a copy of SessionCleanupRejection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? issues = null,}) {
  return _then(_SessionCleanupRejection(
issues: null == issues ? _self._issues : issues // ignore: cast_nullable_to_non_nullable
as List<CleanupIssue>,
  ));
}


}

CleanupIssue _$CleanupIssueFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'unstaged_changes':
          return CleanupIssueUnstagedChanges.fromJson(
            json
          );
                case 'branch_mismatch':
          return CleanupIssueBranchMismatch.fromJson(
            json
          );
                case 'shared_worktree':
          return CleanupIssueSharedWorktree.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'CleanupIssue',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$CleanupIssue {



  /// Serializes this CleanupIssue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CleanupIssue);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CleanupIssue()';
}


}

/// @nodoc
class $CleanupIssueCopyWith<$Res>  {
$CleanupIssueCopyWith(CleanupIssue _, $Res Function(CleanupIssue) __);
}



/// @nodoc
@JsonSerializable()

class CleanupIssueUnstagedChanges implements CleanupIssue {
  const CleanupIssueUnstagedChanges({final  String? $type}): $type = $type ?? 'unstaged_changes';
  factory CleanupIssueUnstagedChanges.fromJson(Map<String, dynamic> json) => _$CleanupIssueUnstagedChangesFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CleanupIssueUnstagedChangesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CleanupIssueUnstagedChanges);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CleanupIssue.unstagedChanges()';
}


}




/// @nodoc
@JsonSerializable()

class CleanupIssueBranchMismatch implements CleanupIssue {
  const CleanupIssueBranchMismatch({required this.expected, required this.actual, final  String? $type}): $type = $type ?? 'branch_mismatch';
  factory CleanupIssueBranchMismatch.fromJson(Map<String, dynamic> json) => _$CleanupIssueBranchMismatchFromJson(json);

 final  String expected;
 final  String actual;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CleanupIssue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CleanupIssueBranchMismatchCopyWith<CleanupIssueBranchMismatch> get copyWith => _$CleanupIssueBranchMismatchCopyWithImpl<CleanupIssueBranchMismatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CleanupIssueBranchMismatchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CleanupIssueBranchMismatch&&(identical(other.expected, expected) || other.expected == expected)&&(identical(other.actual, actual) || other.actual == actual));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,expected,actual);

@override
String toString() {
  return 'CleanupIssue.branchMismatch(expected: $expected, actual: $actual)';
}


}

/// @nodoc
abstract mixin class $CleanupIssueBranchMismatchCopyWith<$Res> implements $CleanupIssueCopyWith<$Res> {
  factory $CleanupIssueBranchMismatchCopyWith(CleanupIssueBranchMismatch value, $Res Function(CleanupIssueBranchMismatch) _then) = _$CleanupIssueBranchMismatchCopyWithImpl;
@useResult
$Res call({
 String expected, String actual
});




}
/// @nodoc
class _$CleanupIssueBranchMismatchCopyWithImpl<$Res>
    implements $CleanupIssueBranchMismatchCopyWith<$Res> {
  _$CleanupIssueBranchMismatchCopyWithImpl(this._self, this._then);

  final CleanupIssueBranchMismatch _self;
  final $Res Function(CleanupIssueBranchMismatch) _then;

/// Create a copy of CleanupIssue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? expected = null,Object? actual = null,}) {
  return _then(CleanupIssueBranchMismatch(
expected: null == expected ? _self.expected : expected // ignore: cast_nullable_to_non_nullable
as String,actual: null == actual ? _self.actual : actual // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CleanupIssueSharedWorktree implements CleanupIssue {
  const CleanupIssueSharedWorktree({final  String? $type}): $type = $type ?? 'shared_worktree';
  factory CleanupIssueSharedWorktree.fromJson(Map<String, dynamic> json) => _$CleanupIssueSharedWorktreeFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CleanupIssueSharedWorktreeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CleanupIssueSharedWorktree);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CleanupIssue.sharedWorktree()';
}


}




// dart format on
