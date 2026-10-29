// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'all_sessions_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AllSessionsRow {

 Session get session; ProjectSummary get project; bool get isRunning; bool get isUnseen; bool get isAwaitingInput; bool get isRetrying; int get backgroundTaskCount;
/// Create a copy of AllSessionsRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AllSessionsRowCopyWith<AllSessionsRow> get copyWith => _$AllSessionsRowCopyWithImpl<AllSessionsRow>(this as AllSessionsRow, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AllSessionsRow;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllSessionsRow&&(identical(other.session, _this.session) || other.session == _this.session)&&(identical(other.project, _this.project) || other.project == _this.project)&&(identical(other.isRunning, _this.isRunning) || other.isRunning == _this.isRunning)&&(identical(other.isUnseen, _this.isUnseen) || other.isUnseen == _this.isUnseen)&&(identical(other.isAwaitingInput, _this.isAwaitingInput) || other.isAwaitingInput == _this.isAwaitingInput)&&(identical(other.isRetrying, _this.isRetrying) || other.isRetrying == _this.isRetrying)&&(identical(other.backgroundTaskCount, _this.backgroundTaskCount) || other.backgroundTaskCount == _this.backgroundTaskCount));
}


@override
int get hashCode {
  final _this = this as AllSessionsRow;
  return Object.hash(runtimeType,_this.session,_this.project,_this.isRunning,_this.isUnseen,_this.isAwaitingInput,_this.isRetrying,_this.backgroundTaskCount);
}

@override
String toString() {
  final _this = this as AllSessionsRow;
  return 'AllSessionsRow(session: ${_this.session}, project: ${_this.project}, isRunning: ${_this.isRunning}, isUnseen: ${_this.isUnseen}, isAwaitingInput: ${_this.isAwaitingInput}, isRetrying: ${_this.isRetrying}, backgroundTaskCount: ${_this.backgroundTaskCount})';
}


}

/// @nodoc
abstract mixin class $AllSessionsRowCopyWith<$Res>  {
  factory $AllSessionsRowCopyWith(AllSessionsRow value, $Res Function(AllSessionsRow) _then) = _$AllSessionsRowCopyWithImpl;
@useResult
$Res call({
 Session session, ProjectSummary project, bool isRunning, bool isUnseen, bool isAwaitingInput, bool isRetrying, int backgroundTaskCount
});


$SessionCopyWith<$Res> get session;$ProjectSummaryCopyWith<$Res> get project;

}
/// @nodoc
class _$AllSessionsRowCopyWithImpl<$Res>
    implements $AllSessionsRowCopyWith<$Res> {
  _$AllSessionsRowCopyWithImpl(this._self, this._then);

  final AllSessionsRow _self;
  final $Res Function(AllSessionsRow) _then;

/// Create a copy of AllSessionsRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? session = null,Object? project = null,Object? isRunning = null,Object? isUnseen = null,Object? isAwaitingInput = null,Object? isRetrying = null,Object? backgroundTaskCount = null,}) {
  return _then(AllSessionsRow(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as ProjectSummary,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,isUnseen: null == isUnseen ? _self.isUnseen : isUnseen // ignore: cast_nullable_to_non_nullable
as bool,isAwaitingInput: null == isAwaitingInput ? _self.isAwaitingInput : isAwaitingInput // ignore: cast_nullable_to_non_nullable
as bool,isRetrying: null == isRetrying ? _self.isRetrying : isRetrying // ignore: cast_nullable_to_non_nullable
as bool,backgroundTaskCount: null == backgroundTaskCount ? _self.backgroundTaskCount : backgroundTaskCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of AllSessionsRow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get session {
  
  return $SessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}/// Create a copy of AllSessionsRow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSummaryCopyWith<$Res> get project {
  
  return $ProjectSummaryCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}



/// @nodoc


class _AllSessionsRow implements AllSessionsRow {
  const _AllSessionsRow({required this.session, required this.project, required this.isRunning, required this.isUnseen, required this.isAwaitingInput, required this.isRetrying, required this.backgroundTaskCount});
  

@override final  Session session;
@override final  ProjectSummary project;
@override final  bool isRunning;
@override final  bool isUnseen;
@override final  bool isAwaitingInput;
@override final  bool isRetrying;
@override final  int backgroundTaskCount;

/// Create a copy of AllSessionsRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AllSessionsRowCopyWith<_AllSessionsRow> get copyWith => __$AllSessionsRowCopyWithImpl<_AllSessionsRow>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AllSessionsRow&&(identical(other.session, session) || other.session == session)&&(identical(other.project, project) || other.project == project)&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.isUnseen, isUnseen) || other.isUnseen == isUnseen)&&(identical(other.isAwaitingInput, isAwaitingInput) || other.isAwaitingInput == isAwaitingInput)&&(identical(other.isRetrying, isRetrying) || other.isRetrying == isRetrying)&&(identical(other.backgroundTaskCount, backgroundTaskCount) || other.backgroundTaskCount == backgroundTaskCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,session,project,isRunning,isUnseen,isAwaitingInput,isRetrying,backgroundTaskCount);
}

@override
String toString() {
    return 'AllSessionsRow(session: $session, project: $project, isRunning: $isRunning, isUnseen: $isUnseen, isAwaitingInput: $isAwaitingInput, isRetrying: $isRetrying, backgroundTaskCount: $backgroundTaskCount)';
}


}

/// @nodoc
abstract mixin class _$AllSessionsRowCopyWith<$Res> implements $AllSessionsRowCopyWith<$Res> {
  factory _$AllSessionsRowCopyWith(_AllSessionsRow value, $Res Function(_AllSessionsRow) _then) = __$AllSessionsRowCopyWithImpl;
@override @useResult
$Res call({
 Session session, ProjectSummary project, bool isRunning, bool isUnseen, bool isAwaitingInput, bool isRetrying, int backgroundTaskCount
});


@override $SessionCopyWith<$Res> get session;@override $ProjectSummaryCopyWith<$Res> get project;

}
/// @nodoc
class __$AllSessionsRowCopyWithImpl<$Res>
    implements _$AllSessionsRowCopyWith<$Res> {
  __$AllSessionsRowCopyWithImpl(this._self, this._then);

  final _AllSessionsRow _self;
  final $Res Function(_AllSessionsRow) _then;

/// Create a copy of AllSessionsRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? session = null,Object? project = null,Object? isRunning = null,Object? isUnseen = null,Object? isAwaitingInput = null,Object? isRetrying = null,Object? backgroundTaskCount = null,}) {
  return _then(_AllSessionsRow(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as ProjectSummary,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,isUnseen: null == isUnseen ? _self.isUnseen : isUnseen // ignore: cast_nullable_to_non_nullable
as bool,isAwaitingInput: null == isAwaitingInput ? _self.isAwaitingInput : isAwaitingInput // ignore: cast_nullable_to_non_nullable
as bool,isRetrying: null == isRetrying ? _self.isRetrying : isRetrying // ignore: cast_nullable_to_non_nullable
as bool,backgroundTaskCount: null == backgroundTaskCount ? _self.backgroundTaskCount : backgroundTaskCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of AllSessionsRow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get session {
  
  return $SessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}/// Create a copy of AllSessionsRow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSummaryCopyWith<$Res> get project {
  
  return $ProjectSummaryCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}

/// @nodoc
mixin _$AllSessionsFailure {

 ProjectSummary get project; RemoteFailureReason get reason;
/// Create a copy of AllSessionsFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AllSessionsFailureCopyWith<AllSessionsFailure> get copyWith => _$AllSessionsFailureCopyWithImpl<AllSessionsFailure>(this as AllSessionsFailure, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AllSessionsFailure;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllSessionsFailure&&(identical(other.project, _this.project) || other.project == _this.project)&&(identical(other.reason, _this.reason) || other.reason == _this.reason));
}


@override
int get hashCode {
  final _this = this as AllSessionsFailure;
  return Object.hash(runtimeType,_this.project,_this.reason);
}

@override
String toString() {
  final _this = this as AllSessionsFailure;
  return 'AllSessionsFailure(project: ${_this.project}, reason: ${_this.reason})';
}


}

/// @nodoc
abstract mixin class $AllSessionsFailureCopyWith<$Res>  {
  factory $AllSessionsFailureCopyWith(AllSessionsFailure value, $Res Function(AllSessionsFailure) _then) = _$AllSessionsFailureCopyWithImpl;
@useResult
$Res call({
 ProjectSummary project, RemoteFailureReason reason
});


$ProjectSummaryCopyWith<$Res> get project;

}
/// @nodoc
class _$AllSessionsFailureCopyWithImpl<$Res>
    implements $AllSessionsFailureCopyWith<$Res> {
  _$AllSessionsFailureCopyWithImpl(this._self, this._then);

  final AllSessionsFailure _self;
  final $Res Function(AllSessionsFailure) _then;

/// Create a copy of AllSessionsFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? project = null,Object? reason = null,}) {
  return _then(AllSessionsFailure(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as ProjectSummary,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}
/// Create a copy of AllSessionsFailure
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSummaryCopyWith<$Res> get project {
  
  return $ProjectSummaryCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}



/// @nodoc


class _AllSessionsFailure implements AllSessionsFailure {
  const _AllSessionsFailure({required this.project, required this.reason});
  

@override final  ProjectSummary project;
@override final  RemoteFailureReason reason;

/// Create a copy of AllSessionsFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AllSessionsFailureCopyWith<_AllSessionsFailure> get copyWith => __$AllSessionsFailureCopyWithImpl<_AllSessionsFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AllSessionsFailure&&(identical(other.project, project) || other.project == project)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,project,reason);
}

@override
String toString() {
    return 'AllSessionsFailure(project: $project, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$AllSessionsFailureCopyWith<$Res> implements $AllSessionsFailureCopyWith<$Res> {
  factory _$AllSessionsFailureCopyWith(_AllSessionsFailure value, $Res Function(_AllSessionsFailure) _then) = __$AllSessionsFailureCopyWithImpl;
@override @useResult
$Res call({
 ProjectSummary project, RemoteFailureReason reason
});


@override $ProjectSummaryCopyWith<$Res> get project;

}
/// @nodoc
class __$AllSessionsFailureCopyWithImpl<$Res>
    implements _$AllSessionsFailureCopyWith<$Res> {
  __$AllSessionsFailureCopyWithImpl(this._self, this._then);

  final _AllSessionsFailure _self;
  final $Res Function(_AllSessionsFailure) _then;

/// Create a copy of AllSessionsFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? project = null,Object? reason = null,}) {
  return _then(_AllSessionsFailure(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as ProjectSummary,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}

/// Create a copy of AllSessionsFailure
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSummaryCopyWith<$Res> get project {
  
  return $ProjectSummaryCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}

/// @nodoc
mixin _$SessionListChipCounts {

 int get all; int get running; int get unread;
/// Create a copy of SessionListChipCounts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListChipCountsCopyWith<SessionListChipCounts> get copyWith => _$SessionListChipCountsCopyWithImpl<SessionListChipCounts>(this as SessionListChipCounts, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SessionListChipCounts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListChipCounts&&(identical(other.all, _this.all) || other.all == _this.all)&&(identical(other.running, _this.running) || other.running == _this.running)&&(identical(other.unread, _this.unread) || other.unread == _this.unread));
}


@override
int get hashCode {
  final _this = this as SessionListChipCounts;
  return Object.hash(runtimeType,_this.all,_this.running,_this.unread);
}

@override
String toString() {
  final _this = this as SessionListChipCounts;
  return 'SessionListChipCounts(all: ${_this.all}, running: ${_this.running}, unread: ${_this.unread})';
}


}

/// @nodoc
abstract mixin class $SessionListChipCountsCopyWith<$Res>  {
  factory $SessionListChipCountsCopyWith(SessionListChipCounts value, $Res Function(SessionListChipCounts) _then) = _$SessionListChipCountsCopyWithImpl;
@useResult
$Res call({
 int all, int running, int unread
});




}
/// @nodoc
class _$SessionListChipCountsCopyWithImpl<$Res>
    implements $SessionListChipCountsCopyWith<$Res> {
  _$SessionListChipCountsCopyWithImpl(this._self, this._then);

  final SessionListChipCounts _self;
  final $Res Function(SessionListChipCounts) _then;

/// Create a copy of SessionListChipCounts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? all = null,Object? running = null,Object? unread = null,}) {
  return _then(SessionListChipCounts(
all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as int,running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as int,unread: null == unread ? _self.unread : unread // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _SessionListChipCounts extends SessionListChipCounts {
  const _SessionListChipCounts({required this.all, required this.running, required this.unread}): super._();
  

@override final  int all;
@override final  int running;
@override final  int unread;

/// Create a copy of SessionListChipCounts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionListChipCountsCopyWith<_SessionListChipCounts> get copyWith => __$SessionListChipCountsCopyWithImpl<_SessionListChipCounts>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionListChipCounts&&(identical(other.all, all) || other.all == all)&&(identical(other.running, running) || other.running == running)&&(identical(other.unread, unread) || other.unread == unread));
}


@override
int get hashCode {
    return Object.hash(runtimeType,all,running,unread);
}

@override
String toString() {
    return 'SessionListChipCounts(all: $all, running: $running, unread: $unread)';
}


}

/// @nodoc
abstract mixin class _$SessionListChipCountsCopyWith<$Res> implements $SessionListChipCountsCopyWith<$Res> {
  factory _$SessionListChipCountsCopyWith(_SessionListChipCounts value, $Res Function(_SessionListChipCounts) _then) = __$SessionListChipCountsCopyWithImpl;
@override @useResult
$Res call({
 int all, int running, int unread
});




}
/// @nodoc
class __$SessionListChipCountsCopyWithImpl<$Res>
    implements _$SessionListChipCountsCopyWith<$Res> {
  __$SessionListChipCountsCopyWithImpl(this._self, this._then);

  final _SessionListChipCounts _self;
  final $Res Function(_SessionListChipCounts) _then;

/// Create a copy of SessionListChipCounts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? all = null,Object? running = null,Object? unread = null,}) {
  return _then(_SessionListChipCounts(
all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as int,running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as int,unread: null == unread ? _self.unread : unread // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$AllSessionsState {

/// The project the list is filtered to, or null for every project.
 String? get projectId; String get query; SessionListQuickFilter get quickFilter;/// Every loaded project's rows in [rows]' order, whatever the filter, the
/// query and the chip, less the hidden sessions: what a jump-to search
/// offers.
 List<AllSessionsRow> get everyProjectRows;/// Newest first, by last update (archived: by archive time) and never by
/// status, narrowed by the filter, the query, the chip and the hidden
/// sessions. Date headings are the presentation's, over this order.
 List<AllSessionsRow> get rows; SessionListChipCounts get counts;/// The listed projects, under the filter, whose sessions failed to load.
 List<AllSessionsFailure> get failures;/// Whether the project list, or a listed project under the filter, is still
/// loading for the first time, or the archived list's reload on open has not
/// answered yet.
 bool get isLoading;/// The bridge's "No project" project, or null on a bridge without one.
 String? get scratchProjectId;/// The new-session default: the filter, otherwise [scratchProjectId],
/// otherwise the project of the newest session, otherwise null. Without
/// either it stays null while [isLoading], so a consumer that holds the
/// first default it sees never holds a project that merely answered first.
 String? get defaultProjectId;
/// Create a copy of AllSessionsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AllSessionsStateCopyWith<AllSessionsState> get copyWith => _$AllSessionsStateCopyWithImpl<AllSessionsState>(this as AllSessionsState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AllSessionsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllSessionsState&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.query, _this.query) || other.query == _this.query)&&(identical(other.quickFilter, _this.quickFilter) || other.quickFilter == _this.quickFilter)&&const DeepCollectionEquality().equals(other.everyProjectRows, _this.everyProjectRows)&&const DeepCollectionEquality().equals(other.rows, _this.rows)&&(identical(other.counts, _this.counts) || other.counts == _this.counts)&&const DeepCollectionEquality().equals(other.failures, _this.failures)&&(identical(other.isLoading, _this.isLoading) || other.isLoading == _this.isLoading)&&(identical(other.scratchProjectId, _this.scratchProjectId) || other.scratchProjectId == _this.scratchProjectId)&&(identical(other.defaultProjectId, _this.defaultProjectId) || other.defaultProjectId == _this.defaultProjectId));
}


@override
int get hashCode {
  final _this = this as AllSessionsState;
  return Object.hash(runtimeType,_this.projectId,_this.query,_this.quickFilter,const DeepCollectionEquality().hash(_this.everyProjectRows),const DeepCollectionEquality().hash(_this.rows),_this.counts,const DeepCollectionEquality().hash(_this.failures),_this.isLoading,_this.scratchProjectId,_this.defaultProjectId);
}

@override
String toString() {
  final _this = this as AllSessionsState;
  return 'AllSessionsState(projectId: ${_this.projectId}, query: ${_this.query}, quickFilter: ${_this.quickFilter}, everyProjectRows: ${_this.everyProjectRows}, rows: ${_this.rows}, counts: ${_this.counts}, failures: ${_this.failures}, isLoading: ${_this.isLoading}, scratchProjectId: ${_this.scratchProjectId}, defaultProjectId: ${_this.defaultProjectId})';
}


}

/// @nodoc
abstract mixin class $AllSessionsStateCopyWith<$Res>  {
  factory $AllSessionsStateCopyWith(AllSessionsState value, $Res Function(AllSessionsState) _then) = _$AllSessionsStateCopyWithImpl;
@useResult
$Res call({
 String? projectId, String query, SessionListQuickFilter quickFilter, List<AllSessionsRow> everyProjectRows, List<AllSessionsRow> rows, SessionListChipCounts counts, List<AllSessionsFailure> failures, bool isLoading, String? scratchProjectId, String? defaultProjectId
});


$SessionListChipCountsCopyWith<$Res> get counts;

}
/// @nodoc
class _$AllSessionsStateCopyWithImpl<$Res>
    implements $AllSessionsStateCopyWith<$Res> {
  _$AllSessionsStateCopyWithImpl(this._self, this._then);

  final AllSessionsState _self;
  final $Res Function(AllSessionsState) _then;

/// Create a copy of AllSessionsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = freezed,Object? query = null,Object? quickFilter = null,Object? everyProjectRows = null,Object? rows = null,Object? counts = null,Object? failures = null,Object? isLoading = null,Object? scratchProjectId = freezed,Object? defaultProjectId = freezed,}) {
  return _then(AllSessionsState(
projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,quickFilter: null == quickFilter ? _self.quickFilter : quickFilter // ignore: cast_nullable_to_non_nullable
as SessionListQuickFilter,everyProjectRows: null == everyProjectRows ? _self.everyProjectRows : everyProjectRows // ignore: cast_nullable_to_non_nullable
as List<AllSessionsRow>,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<AllSessionsRow>,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as SessionListChipCounts,failures: null == failures ? _self.failures : failures // ignore: cast_nullable_to_non_nullable
as List<AllSessionsFailure>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,scratchProjectId: freezed == scratchProjectId ? _self.scratchProjectId : scratchProjectId // ignore: cast_nullable_to_non_nullable
as String?,defaultProjectId: freezed == defaultProjectId ? _self.defaultProjectId : defaultProjectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AllSessionsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionListChipCountsCopyWith<$Res> get counts {
  
  return $SessionListChipCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}



/// @nodoc


class _AllSessionsState implements AllSessionsState {
  const _AllSessionsState({required this.projectId, required this.query, required this.quickFilter, required this.everyProjectRows, required this.rows, required this.counts, required this.failures, required this.isLoading, required this.scratchProjectId, required this.defaultProjectId});
  

/// The project the list is filtered to, or null for every project.
@override final  String? projectId;
@override final  String query;
@override final  SessionListQuickFilter quickFilter;
/// Every loaded project's rows in [rows]' order, whatever the filter, the
/// query and the chip, less the hidden sessions: what a jump-to search
/// offers.
@override final  List<AllSessionsRow> everyProjectRows;
/// Newest first, by last update (archived: by archive time) and never by
/// status, narrowed by the filter, the query, the chip and the hidden
/// sessions. Date headings are the presentation's, over this order.
@override final  List<AllSessionsRow> rows;
@override final  SessionListChipCounts counts;
/// The listed projects, under the filter, whose sessions failed to load.
@override final  List<AllSessionsFailure> failures;
/// Whether the project list, or a listed project under the filter, is still
/// loading for the first time, or the archived list's reload on open has not
/// answered yet.
@override final  bool isLoading;
/// The bridge's "No project" project, or null on a bridge without one.
@override final  String? scratchProjectId;
/// The new-session default: the filter, otherwise [scratchProjectId],
/// otherwise the project of the newest session, otherwise null. Without
/// either it stays null while [isLoading], so a consumer that holds the
/// first default it sees never holds a project that merely answered first.
@override final  String? defaultProjectId;

/// Create a copy of AllSessionsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AllSessionsStateCopyWith<_AllSessionsState> get copyWith => __$AllSessionsStateCopyWithImpl<_AllSessionsState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AllSessionsState&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.query, query) || other.query == query)&&(identical(other.quickFilter, quickFilter) || other.quickFilter == quickFilter)&&const DeepCollectionEquality().equals(other.everyProjectRows, everyProjectRows)&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.counts, counts) || other.counts == counts)&&const DeepCollectionEquality().equals(other.failures, failures)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.scratchProjectId, scratchProjectId) || other.scratchProjectId == scratchProjectId)&&(identical(other.defaultProjectId, defaultProjectId) || other.defaultProjectId == defaultProjectId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,projectId,query,quickFilter,const DeepCollectionEquality().hash(everyProjectRows),const DeepCollectionEquality().hash(rows),counts,const DeepCollectionEquality().hash(failures),isLoading,scratchProjectId,defaultProjectId);
}

@override
String toString() {
    return 'AllSessionsState(projectId: $projectId, query: $query, quickFilter: $quickFilter, everyProjectRows: $everyProjectRows, rows: $rows, counts: $counts, failures: $failures, isLoading: $isLoading, scratchProjectId: $scratchProjectId, defaultProjectId: $defaultProjectId)';
}


}

/// @nodoc
abstract mixin class _$AllSessionsStateCopyWith<$Res> implements $AllSessionsStateCopyWith<$Res> {
  factory _$AllSessionsStateCopyWith(_AllSessionsState value, $Res Function(_AllSessionsState) _then) = __$AllSessionsStateCopyWithImpl;
@override @useResult
$Res call({
 String? projectId, String query, SessionListQuickFilter quickFilter, List<AllSessionsRow> everyProjectRows, List<AllSessionsRow> rows, SessionListChipCounts counts, List<AllSessionsFailure> failures, bool isLoading, String? scratchProjectId, String? defaultProjectId
});


@override $SessionListChipCountsCopyWith<$Res> get counts;

}
/// @nodoc
class __$AllSessionsStateCopyWithImpl<$Res>
    implements _$AllSessionsStateCopyWith<$Res> {
  __$AllSessionsStateCopyWithImpl(this._self, this._then);

  final _AllSessionsState _self;
  final $Res Function(_AllSessionsState) _then;

/// Create a copy of AllSessionsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = freezed,Object? query = null,Object? quickFilter = null,Object? everyProjectRows = null,Object? rows = null,Object? counts = null,Object? failures = null,Object? isLoading = null,Object? scratchProjectId = freezed,Object? defaultProjectId = freezed,}) {
  return _then(_AllSessionsState(
projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,quickFilter: null == quickFilter ? _self.quickFilter : quickFilter // ignore: cast_nullable_to_non_nullable
as SessionListQuickFilter,everyProjectRows: null == everyProjectRows ? _self.everyProjectRows : everyProjectRows // ignore: cast_nullable_to_non_nullable
as List<AllSessionsRow>,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<AllSessionsRow>,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as SessionListChipCounts,failures: null == failures ? _self.failures : failures // ignore: cast_nullable_to_non_nullable
as List<AllSessionsFailure>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,scratchProjectId: freezed == scratchProjectId ? _self.scratchProjectId : scratchProjectId // ignore: cast_nullable_to_non_nullable
as String?,defaultProjectId: freezed == defaultProjectId ? _self.defaultProjectId : defaultProjectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AllSessionsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionListChipCountsCopyWith<$Res> get counts {
  
  return $SessionListChipCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}

// dart format on
