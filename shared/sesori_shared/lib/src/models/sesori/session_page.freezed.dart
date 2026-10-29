// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionPageRequest {

 SessionPageMode get mode;/// Null lists every visible project.
 String? get projectId;/// Null means no search; a query must hold at least one word.
 String? get query; SessionPageFilter get filter;/// The previous page's [SessionPageResponse.nextCursor]; null for the
/// first page.
 String? get cursor;/// From 0 to 1000. Zero asks for the counts only.
 int get limit;

  /// Serializes this SessionPageRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPageRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPageRequest&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.query, _this.query) || other.query == _this.query)&&(identical(other.filter, _this.filter) || other.filter == _this.filter)&&(identical(other.cursor, _this.cursor) || other.cursor == _this.cursor)&&(identical(other.limit, _this.limit) || other.limit == _this.limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPageRequest;
  return Object.hash(runtimeType,_this.mode,_this.projectId,_this.query,_this.filter,_this.cursor,_this.limit);
}

@override
String toString() {
  final _this = this as SessionPageRequest;
  return 'SessionPageRequest(mode: ${_this.mode}, projectId: ${_this.projectId}, query: ${_this.query}, filter: ${_this.filter}, cursor: ${_this.cursor}, limit: ${_this.limit})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionPageRequest implements SessionPageRequest {
  const _SessionPageRequest({required this.mode, required this.projectId, required this.query, required this.filter, required this.cursor, required this.limit});
  factory _SessionPageRequest.fromJson(Map<String, dynamic> json) => _$SessionPageRequestFromJson(json);

@override final  SessionPageMode mode;
/// Null lists every visible project.
@override final  String? projectId;
/// Null means no search; a query must hold at least one word.
@override final  String? query;
@override final  SessionPageFilter filter;
/// The previous page's [SessionPageResponse.nextCursor]; null for the
/// first page.
@override final  String? cursor;
/// From 0 to 1000. Zero asks for the counts only.
@override final  int limit;


@override
Map<String, dynamic> toJson() {
  return _$SessionPageRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPageRequest&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.query, query) || other.query == query)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mode,projectId,query,filter,cursor,limit);
}

@override
String toString() {
    return 'SessionPageRequest(mode: $mode, projectId: $projectId, query: $query, filter: $filter, cursor: $cursor, limit: $limit)';
}


}





/// @nodoc
mixin _$SessionPageResponse {

 List<Session> get items;/// Null when no rows follow this page, and for a counts-only request.
 String? get nextCursor; SessionPageCounts get counts;

  /// Serializes this SessionPageResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPageResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPageResponse&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.nextCursor, _this.nextCursor) || other.nextCursor == _this.nextCursor)&&(identical(other.counts, _this.counts) || other.counts == _this.counts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPageResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items),_this.nextCursor,_this.counts);
}

@override
String toString() {
  final _this = this as SessionPageResponse;
  return 'SessionPageResponse(items: ${_this.items}, nextCursor: ${_this.nextCursor}, counts: ${_this.counts})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionPageResponse implements SessionPageResponse {
  const _SessionPageResponse({required  List<Session> items, required this.nextCursor, required this.counts}): _items = items;
  factory _SessionPageResponse.fromJson(Map<String, dynamic> json) => _$SessionPageResponseFromJson(json);

 final  List<Session> _items;
@override List<Session> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

/// Null when no rows follow this page, and for a counts-only request.
@override final  String? nextCursor;
@override final  SessionPageCounts counts;


@override
Map<String, dynamic> toJson() {
  return _$SessionPageResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPageResponse&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.counts, counts) || other.counts == counts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),nextCursor,counts);
}

@override
String toString() {
    return 'SessionPageResponse(items: $items, nextCursor: $nextCursor, counts: $counts)';
}


}





/// @nodoc
mixin _$SessionPageCounts {

 int get all; int get running; int get unread;

  /// Serializes this SessionPageCounts to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPageCounts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPageCounts&&(identical(other.all, _this.all) || other.all == _this.all)&&(identical(other.running, _this.running) || other.running == _this.running)&&(identical(other.unread, _this.unread) || other.unread == _this.unread));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPageCounts;
  return Object.hash(runtimeType,_this.all,_this.running,_this.unread);
}

@override
String toString() {
  final _this = this as SessionPageCounts;
  return 'SessionPageCounts(all: ${_this.all}, running: ${_this.running}, unread: ${_this.unread})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionPageCounts implements SessionPageCounts {
  const _SessionPageCounts({required this.all, required this.running, required this.unread});
  factory _SessionPageCounts.fromJson(Map<String, dynamic> json) => _$SessionPageCountsFromJson(json);

@override final  int all;
@override final  int running;
@override final  int unread;


@override
Map<String, dynamic> toJson() {
  return _$SessionPageCountsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPageCounts&&(identical(other.all, all) || other.all == all)&&(identical(other.running, running) || other.running == running)&&(identical(other.unread, unread) || other.unread == unread));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,all,running,unread);
}

@override
String toString() {
    return 'SessionPageCounts(all: $all, running: $running, unread: $unread)';
}


}




// dart format on
