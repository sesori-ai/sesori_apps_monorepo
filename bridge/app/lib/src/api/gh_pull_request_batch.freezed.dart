// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gh_pull_request_batch.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GhPullRequestBatchResponse {

 int get errorCount; String get viewerLogin; List<GhPullRequestCandidatePage> get pages;
/// Create a copy of GhPullRequestBatchResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhPullRequestBatchResponseCopyWith<GhPullRequestBatchResponse> get copyWith => _$GhPullRequestBatchResponseCopyWithImpl<GhPullRequestBatchResponse>(this as GhPullRequestBatchResponse, _$identity);

  /// Serializes this GhPullRequestBatchResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhPullRequestBatchResponse&&(identical(other.errorCount, errorCount) || other.errorCount == errorCount)&&(identical(other.viewerLogin, viewerLogin) || other.viewerLogin == viewerLogin)&&const DeepCollectionEquality().equals(other.pages, pages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,errorCount,viewerLogin,const DeepCollectionEquality().hash(pages));

@override
String toString() {
  return 'GhPullRequestBatchResponse(errorCount: $errorCount, viewerLogin: $viewerLogin, pages: $pages)';
}


}

/// @nodoc
abstract mixin class $GhPullRequestBatchResponseCopyWith<$Res>  {
  factory $GhPullRequestBatchResponseCopyWith(GhPullRequestBatchResponse value, $Res Function(GhPullRequestBatchResponse) _then) = _$GhPullRequestBatchResponseCopyWithImpl;
@useResult
$Res call({
 int errorCount, String viewerLogin, List<GhPullRequestCandidatePage> pages
});




}
/// @nodoc
class _$GhPullRequestBatchResponseCopyWithImpl<$Res>
    implements $GhPullRequestBatchResponseCopyWith<$Res> {
  _$GhPullRequestBatchResponseCopyWithImpl(this._self, this._then);

  final GhPullRequestBatchResponse _self;
  final $Res Function(GhPullRequestBatchResponse) _then;

/// Create a copy of GhPullRequestBatchResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? errorCount = null,Object? viewerLogin = null,Object? pages = null,}) {
  return _then(_self.copyWith(
errorCount: null == errorCount ? _self.errorCount : errorCount // ignore: cast_nullable_to_non_nullable
as int,viewerLogin: null == viewerLogin ? _self.viewerLogin : viewerLogin // ignore: cast_nullable_to_non_nullable
as String,pages: null == pages ? _self.pages : pages // ignore: cast_nullable_to_non_nullable
as List<GhPullRequestCandidatePage>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _GhPullRequestBatchResponse implements GhPullRequestBatchResponse {
  const _GhPullRequestBatchResponse({required this.errorCount, required this.viewerLogin, required final  List<GhPullRequestCandidatePage> pages}): _pages = pages;
  factory _GhPullRequestBatchResponse.fromJson(Map<String, dynamic> json) => _$GhPullRequestBatchResponseFromJson(json);

@override final  int errorCount;
@override final  String viewerLogin;
 final  List<GhPullRequestCandidatePage> _pages;
@override List<GhPullRequestCandidatePage> get pages {
  if (_pages is EqualUnmodifiableListView) return _pages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pages);
}


/// Create a copy of GhPullRequestBatchResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhPullRequestBatchResponseCopyWith<_GhPullRequestBatchResponse> get copyWith => __$GhPullRequestBatchResponseCopyWithImpl<_GhPullRequestBatchResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GhPullRequestBatchResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhPullRequestBatchResponse&&(identical(other.errorCount, errorCount) || other.errorCount == errorCount)&&(identical(other.viewerLogin, viewerLogin) || other.viewerLogin == viewerLogin)&&const DeepCollectionEquality().equals(other._pages, _pages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,errorCount,viewerLogin,const DeepCollectionEquality().hash(_pages));

@override
String toString() {
  return 'GhPullRequestBatchResponse(errorCount: $errorCount, viewerLogin: $viewerLogin, pages: $pages)';
}


}

/// @nodoc
abstract mixin class _$GhPullRequestBatchResponseCopyWith<$Res> implements $GhPullRequestBatchResponseCopyWith<$Res> {
  factory _$GhPullRequestBatchResponseCopyWith(_GhPullRequestBatchResponse value, $Res Function(_GhPullRequestBatchResponse) _then) = __$GhPullRequestBatchResponseCopyWithImpl;
@override @useResult
$Res call({
 int errorCount, String viewerLogin, List<GhPullRequestCandidatePage> pages
});




}
/// @nodoc
class __$GhPullRequestBatchResponseCopyWithImpl<$Res>
    implements _$GhPullRequestBatchResponseCopyWith<$Res> {
  __$GhPullRequestBatchResponseCopyWithImpl(this._self, this._then);

  final _GhPullRequestBatchResponse _self;
  final $Res Function(_GhPullRequestBatchResponse) _then;

/// Create a copy of GhPullRequestBatchResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? errorCount = null,Object? viewerLogin = null,Object? pages = null,}) {
  return _then(_GhPullRequestBatchResponse(
errorCount: null == errorCount ? _self.errorCount : errorCount // ignore: cast_nullable_to_non_nullable
as int,viewerLogin: null == viewerLogin ? _self.viewerLogin : viewerLogin // ignore: cast_nullable_to_non_nullable
as String,pages: null == pages ? _self._pages : pages // ignore: cast_nullable_to_non_nullable
as List<GhPullRequestCandidatePage>,
  ));
}


}


/// @nodoc
mixin _$GhPullRequestCandidatePage {

 int get requestIndex; GhPullRequestStateGroup get stateGroup; String get repositoryIdentity; GhPullRequestConnection get connection;
/// Create a copy of GhPullRequestCandidatePage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhPullRequestCandidatePageCopyWith<GhPullRequestCandidatePage> get copyWith => _$GhPullRequestCandidatePageCopyWithImpl<GhPullRequestCandidatePage>(this as GhPullRequestCandidatePage, _$identity);

  /// Serializes this GhPullRequestCandidatePage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhPullRequestCandidatePage&&(identical(other.requestIndex, requestIndex) || other.requestIndex == requestIndex)&&(identical(other.stateGroup, stateGroup) || other.stateGroup == stateGroup)&&(identical(other.repositoryIdentity, repositoryIdentity) || other.repositoryIdentity == repositoryIdentity)&&(identical(other.connection, connection) || other.connection == connection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestIndex,stateGroup,repositoryIdentity,connection);

@override
String toString() {
  return 'GhPullRequestCandidatePage(requestIndex: $requestIndex, stateGroup: $stateGroup, repositoryIdentity: $repositoryIdentity, connection: $connection)';
}


}

/// @nodoc
abstract mixin class $GhPullRequestCandidatePageCopyWith<$Res>  {
  factory $GhPullRequestCandidatePageCopyWith(GhPullRequestCandidatePage value, $Res Function(GhPullRequestCandidatePage) _then) = _$GhPullRequestCandidatePageCopyWithImpl;
@useResult
$Res call({
 int requestIndex, GhPullRequestStateGroup stateGroup, String repositoryIdentity, GhPullRequestConnection connection
});


$GhPullRequestConnectionCopyWith<$Res> get connection;

}
/// @nodoc
class _$GhPullRequestCandidatePageCopyWithImpl<$Res>
    implements $GhPullRequestCandidatePageCopyWith<$Res> {
  _$GhPullRequestCandidatePageCopyWithImpl(this._self, this._then);

  final GhPullRequestCandidatePage _self;
  final $Res Function(GhPullRequestCandidatePage) _then;

/// Create a copy of GhPullRequestCandidatePage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestIndex = null,Object? stateGroup = null,Object? repositoryIdentity = null,Object? connection = null,}) {
  return _then(_self.copyWith(
requestIndex: null == requestIndex ? _self.requestIndex : requestIndex // ignore: cast_nullable_to_non_nullable
as int,stateGroup: null == stateGroup ? _self.stateGroup : stateGroup // ignore: cast_nullable_to_non_nullable
as GhPullRequestStateGroup,repositoryIdentity: null == repositoryIdentity ? _self.repositoryIdentity : repositoryIdentity // ignore: cast_nullable_to_non_nullable
as String,connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as GhPullRequestConnection,
  ));
}
/// Create a copy of GhPullRequestCandidatePage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPullRequestConnectionCopyWith<$Res> get connection {
  
  return $GhPullRequestConnectionCopyWith<$Res>(_self.connection, (value) {
    return _then(_self.copyWith(connection: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _GhPullRequestCandidatePage implements GhPullRequestCandidatePage {
  const _GhPullRequestCandidatePage({required this.requestIndex, required this.stateGroup, required this.repositoryIdentity, required this.connection});
  factory _GhPullRequestCandidatePage.fromJson(Map<String, dynamic> json) => _$GhPullRequestCandidatePageFromJson(json);

@override final  int requestIndex;
@override final  GhPullRequestStateGroup stateGroup;
@override final  String repositoryIdentity;
@override final  GhPullRequestConnection connection;

/// Create a copy of GhPullRequestCandidatePage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhPullRequestCandidatePageCopyWith<_GhPullRequestCandidatePage> get copyWith => __$GhPullRequestCandidatePageCopyWithImpl<_GhPullRequestCandidatePage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GhPullRequestCandidatePageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhPullRequestCandidatePage&&(identical(other.requestIndex, requestIndex) || other.requestIndex == requestIndex)&&(identical(other.stateGroup, stateGroup) || other.stateGroup == stateGroup)&&(identical(other.repositoryIdentity, repositoryIdentity) || other.repositoryIdentity == repositoryIdentity)&&(identical(other.connection, connection) || other.connection == connection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestIndex,stateGroup,repositoryIdentity,connection);

@override
String toString() {
  return 'GhPullRequestCandidatePage(requestIndex: $requestIndex, stateGroup: $stateGroup, repositoryIdentity: $repositoryIdentity, connection: $connection)';
}


}

/// @nodoc
abstract mixin class _$GhPullRequestCandidatePageCopyWith<$Res> implements $GhPullRequestCandidatePageCopyWith<$Res> {
  factory _$GhPullRequestCandidatePageCopyWith(_GhPullRequestCandidatePage value, $Res Function(_GhPullRequestCandidatePage) _then) = __$GhPullRequestCandidatePageCopyWithImpl;
@override @useResult
$Res call({
 int requestIndex, GhPullRequestStateGroup stateGroup, String repositoryIdentity, GhPullRequestConnection connection
});


@override $GhPullRequestConnectionCopyWith<$Res> get connection;

}
/// @nodoc
class __$GhPullRequestCandidatePageCopyWithImpl<$Res>
    implements _$GhPullRequestCandidatePageCopyWith<$Res> {
  __$GhPullRequestCandidatePageCopyWithImpl(this._self, this._then);

  final _GhPullRequestCandidatePage _self;
  final $Res Function(_GhPullRequestCandidatePage) _then;

/// Create a copy of GhPullRequestCandidatePage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestIndex = null,Object? stateGroup = null,Object? repositoryIdentity = null,Object? connection = null,}) {
  return _then(_GhPullRequestCandidatePage(
requestIndex: null == requestIndex ? _self.requestIndex : requestIndex // ignore: cast_nullable_to_non_nullable
as int,stateGroup: null == stateGroup ? _self.stateGroup : stateGroup // ignore: cast_nullable_to_non_nullable
as GhPullRequestStateGroup,repositoryIdentity: null == repositoryIdentity ? _self.repositoryIdentity : repositoryIdentity // ignore: cast_nullable_to_non_nullable
as String,connection: null == connection ? _self.connection : connection // ignore: cast_nullable_to_non_nullable
as GhPullRequestConnection,
  ));
}

/// Create a copy of GhPullRequestCandidatePage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPullRequestConnectionCopyWith<$Res> get connection {
  
  return $GhPullRequestConnectionCopyWith<$Res>(_self.connection, (value) {
    return _then(_self.copyWith(connection: value));
  });
}
}


/// @nodoc
mixin _$GhPullRequestConnection {

 List<GhPullRequest> get nodes; GhPullRequestPageInfo get pageInfo;
/// Create a copy of GhPullRequestConnection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhPullRequestConnectionCopyWith<GhPullRequestConnection> get copyWith => _$GhPullRequestConnectionCopyWithImpl<GhPullRequestConnection>(this as GhPullRequestConnection, _$identity);

  /// Serializes this GhPullRequestConnection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhPullRequestConnection&&const DeepCollectionEquality().equals(other.nodes, nodes)&&(identical(other.pageInfo, pageInfo) || other.pageInfo == pageInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(nodes),pageInfo);

@override
String toString() {
  return 'GhPullRequestConnection(nodes: $nodes, pageInfo: $pageInfo)';
}


}

/// @nodoc
abstract mixin class $GhPullRequestConnectionCopyWith<$Res>  {
  factory $GhPullRequestConnectionCopyWith(GhPullRequestConnection value, $Res Function(GhPullRequestConnection) _then) = _$GhPullRequestConnectionCopyWithImpl;
@useResult
$Res call({
 List<GhPullRequest> nodes, GhPullRequestPageInfo pageInfo
});


$GhPullRequestPageInfoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class _$GhPullRequestConnectionCopyWithImpl<$Res>
    implements $GhPullRequestConnectionCopyWith<$Res> {
  _$GhPullRequestConnectionCopyWithImpl(this._self, this._then);

  final GhPullRequestConnection _self;
  final $Res Function(GhPullRequestConnection) _then;

/// Create a copy of GhPullRequestConnection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodes = null,Object? pageInfo = null,}) {
  return _then(_self.copyWith(
nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhPullRequest>,pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPullRequestPageInfo,
  ));
}
/// Create a copy of GhPullRequestConnection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPullRequestPageInfoCopyWith<$Res> get pageInfo {
  
  return $GhPullRequestPageInfoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _GhPullRequestConnection implements GhPullRequestConnection {
  const _GhPullRequestConnection({required final  List<GhPullRequest> nodes, required this.pageInfo}): _nodes = nodes;
  factory _GhPullRequestConnection.fromJson(Map<String, dynamic> json) => _$GhPullRequestConnectionFromJson(json);

 final  List<GhPullRequest> _nodes;
@override List<GhPullRequest> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}

@override final  GhPullRequestPageInfo pageInfo;

/// Create a copy of GhPullRequestConnection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhPullRequestConnectionCopyWith<_GhPullRequestConnection> get copyWith => __$GhPullRequestConnectionCopyWithImpl<_GhPullRequestConnection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GhPullRequestConnectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhPullRequestConnection&&const DeepCollectionEquality().equals(other._nodes, _nodes)&&(identical(other.pageInfo, pageInfo) || other.pageInfo == pageInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_nodes),pageInfo);

@override
String toString() {
  return 'GhPullRequestConnection(nodes: $nodes, pageInfo: $pageInfo)';
}


}

/// @nodoc
abstract mixin class _$GhPullRequestConnectionCopyWith<$Res> implements $GhPullRequestConnectionCopyWith<$Res> {
  factory _$GhPullRequestConnectionCopyWith(_GhPullRequestConnection value, $Res Function(_GhPullRequestConnection) _then) = __$GhPullRequestConnectionCopyWithImpl;
@override @useResult
$Res call({
 List<GhPullRequest> nodes, GhPullRequestPageInfo pageInfo
});


@override $GhPullRequestPageInfoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class __$GhPullRequestConnectionCopyWithImpl<$Res>
    implements _$GhPullRequestConnectionCopyWith<$Res> {
  __$GhPullRequestConnectionCopyWithImpl(this._self, this._then);

  final _GhPullRequestConnection _self;
  final $Res Function(_GhPullRequestConnection) _then;

/// Create a copy of GhPullRequestConnection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodes = null,Object? pageInfo = null,}) {
  return _then(_GhPullRequestConnection(
nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhPullRequest>,pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPullRequestPageInfo,
  ));
}

/// Create a copy of GhPullRequestConnection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPullRequestPageInfoCopyWith<$Res> get pageInfo {
  
  return $GhPullRequestPageInfoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}


/// @nodoc
mixin _$GhPullRequestPageInfo {

 bool get hasNextPage; String? get endCursor;
/// Create a copy of GhPullRequestPageInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhPullRequestPageInfoCopyWith<GhPullRequestPageInfo> get copyWith => _$GhPullRequestPageInfoCopyWithImpl<GhPullRequestPageInfo>(this as GhPullRequestPageInfo, _$identity);

  /// Serializes this GhPullRequestPageInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhPullRequestPageInfo&&(identical(other.hasNextPage, hasNextPage) || other.hasNextPage == hasNextPage)&&(identical(other.endCursor, endCursor) || other.endCursor == endCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hasNextPage,endCursor);

@override
String toString() {
  return 'GhPullRequestPageInfo(hasNextPage: $hasNextPage, endCursor: $endCursor)';
}


}

/// @nodoc
abstract mixin class $GhPullRequestPageInfoCopyWith<$Res>  {
  factory $GhPullRequestPageInfoCopyWith(GhPullRequestPageInfo value, $Res Function(GhPullRequestPageInfo) _then) = _$GhPullRequestPageInfoCopyWithImpl;
@useResult
$Res call({
 bool hasNextPage, String? endCursor
});




}
/// @nodoc
class _$GhPullRequestPageInfoCopyWithImpl<$Res>
    implements $GhPullRequestPageInfoCopyWith<$Res> {
  _$GhPullRequestPageInfoCopyWithImpl(this._self, this._then);

  final GhPullRequestPageInfo _self;
  final $Res Function(GhPullRequestPageInfo) _then;

/// Create a copy of GhPullRequestPageInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hasNextPage = null,Object? endCursor = freezed,}) {
  return _then(_self.copyWith(
hasNextPage: null == hasNextPage ? _self.hasNextPage : hasNextPage // ignore: cast_nullable_to_non_nullable
as bool,endCursor: freezed == endCursor ? _self.endCursor : endCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _GhPullRequestPageInfo implements GhPullRequestPageInfo {
  const _GhPullRequestPageInfo({required this.hasNextPage, required this.endCursor});
  factory _GhPullRequestPageInfo.fromJson(Map<String, dynamic> json) => _$GhPullRequestPageInfoFromJson(json);

@override final  bool hasNextPage;
@override final  String? endCursor;

/// Create a copy of GhPullRequestPageInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhPullRequestPageInfoCopyWith<_GhPullRequestPageInfo> get copyWith => __$GhPullRequestPageInfoCopyWithImpl<_GhPullRequestPageInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GhPullRequestPageInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhPullRequestPageInfo&&(identical(other.hasNextPage, hasNextPage) || other.hasNextPage == hasNextPage)&&(identical(other.endCursor, endCursor) || other.endCursor == endCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hasNextPage,endCursor);

@override
String toString() {
  return 'GhPullRequestPageInfo(hasNextPage: $hasNextPage, endCursor: $endCursor)';
}


}

/// @nodoc
abstract mixin class _$GhPullRequestPageInfoCopyWith<$Res> implements $GhPullRequestPageInfoCopyWith<$Res> {
  factory _$GhPullRequestPageInfoCopyWith(_GhPullRequestPageInfo value, $Res Function(_GhPullRequestPageInfo) _then) = __$GhPullRequestPageInfoCopyWithImpl;
@override @useResult
$Res call({
 bool hasNextPage, String? endCursor
});




}
/// @nodoc
class __$GhPullRequestPageInfoCopyWithImpl<$Res>
    implements _$GhPullRequestPageInfoCopyWith<$Res> {
  __$GhPullRequestPageInfoCopyWithImpl(this._self, this._then);

  final _GhPullRequestPageInfo _self;
  final $Res Function(_GhPullRequestPageInfo) _then;

/// Create a copy of GhPullRequestPageInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hasNextPage = null,Object? endCursor = freezed,}) {
  return _then(_GhPullRequestPageInfo(
hasNextPage: null == hasNextPage ? _self.hasNextPage : hasNextPage // ignore: cast_nullable_to_non_nullable
as bool,endCursor: freezed == endCursor ? _self.endCursor : endCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
