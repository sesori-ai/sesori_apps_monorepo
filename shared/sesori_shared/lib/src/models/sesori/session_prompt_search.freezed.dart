// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_prompt_search.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionPromptSearchRequest {

 String get sessionId; String get query;

  /// Serializes this SessionPromptSearchRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPromptSearchRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPromptSearchRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.query, _this.query) || other.query == _this.query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPromptSearchRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.query);
}

@override
String toString() {
  final _this = this as SessionPromptSearchRequest;
  return 'SessionPromptSearchRequest(sessionId: ${_this.sessionId}, query: ${_this.query})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionPromptSearchRequest implements SessionPromptSearchRequest {
  const _SessionPromptSearchRequest({required this.sessionId, required this.query});
  factory _SessionPromptSearchRequest.fromJson(Map<String, dynamic> json) => _$SessionPromptSearchRequestFromJson(json);

@override final  String sessionId;
@override final  String query;


@override
Map<String, dynamic> toJson() {
  return _$SessionPromptSearchRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPromptSearchRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.query, query) || other.query == query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,query);
}

@override
String toString() {
    return 'SessionPromptSearchRequest(sessionId: $sessionId, query: $query)';
}


}





/// @nodoc
mixin _$SessionPromptSearchResponse {

 List<SessionPromptSearchMatch> get matches;

  /// Serializes this SessionPromptSearchResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPromptSearchResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPromptSearchResponse&&const DeepCollectionEquality().equals(other.matches, _this.matches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPromptSearchResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.matches));
}

@override
String toString() {
  final _this = this as SessionPromptSearchResponse;
  return 'SessionPromptSearchResponse(matches: ${_this.matches})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionPromptSearchResponse implements SessionPromptSearchResponse {
  const _SessionPromptSearchResponse({required  List<SessionPromptSearchMatch> matches}): _matches = matches;
  factory _SessionPromptSearchResponse.fromJson(Map<String, dynamic> json) => _$SessionPromptSearchResponseFromJson(json);

 final  List<SessionPromptSearchMatch> _matches;
@override List<SessionPromptSearchMatch> get matches {
  if (_matches is EqualUnmodifiableListView) return _matches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_matches);
}



@override
Map<String, dynamic> toJson() {
  return _$SessionPromptSearchResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPromptSearchResponse&&const DeepCollectionEquality().equals(other.matches, _matches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_matches));
}

@override
String toString() {
    return 'SessionPromptSearchResponse(matches: $matches)';
}


}





/// @nodoc
mixin _$SessionPromptSearchMatch {

 String get messageId; SessionPromptExcerpt get excerpt;

  /// Serializes this SessionPromptSearchMatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPromptSearchMatch;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPromptSearchMatch&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPromptSearchMatch;
  return Object.hash(runtimeType,_this.messageId,_this.excerpt);
}

@override
String toString() {
  final _this = this as SessionPromptSearchMatch;
  return 'SessionPromptSearchMatch(messageId: ${_this.messageId}, excerpt: ${_this.excerpt})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionPromptSearchMatch implements SessionPromptSearchMatch {
  const _SessionPromptSearchMatch({required this.messageId, required this.excerpt});
  factory _SessionPromptSearchMatch.fromJson(Map<String, dynamic> json) => _$SessionPromptSearchMatchFromJson(json);

@override final  String messageId;
@override final  SessionPromptExcerpt excerpt;


@override
Map<String, dynamic> toJson() {
  return _$SessionPromptSearchMatchToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPromptSearchMatch&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,messageId,excerpt);
}

@override
String toString() {
    return 'SessionPromptSearchMatch(messageId: $messageId, excerpt: $excerpt)';
}


}





/// @nodoc
mixin _$SessionPromptExcerpt {

 String get before; String get match; String get after;

  /// Serializes this SessionPromptExcerpt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPromptExcerpt;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPromptExcerpt&&(identical(other.before, _this.before) || other.before == _this.before)&&(identical(other.match, _this.match) || other.match == _this.match)&&(identical(other.after, _this.after) || other.after == _this.after));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPromptExcerpt;
  return Object.hash(runtimeType,_this.before,_this.match,_this.after);
}

@override
String toString() {
  final _this = this as SessionPromptExcerpt;
  return 'SessionPromptExcerpt(before: ${_this.before}, match: ${_this.match}, after: ${_this.after})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionPromptExcerpt implements SessionPromptExcerpt {
  const _SessionPromptExcerpt({required this.before, required this.match, required this.after});
  factory _SessionPromptExcerpt.fromJson(Map<String, dynamic> json) => _$SessionPromptExcerptFromJson(json);

@override final  String before;
@override final  String match;
@override final  String after;


@override
Map<String, dynamic> toJson() {
  return _$SessionPromptExcerptToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPromptExcerpt&&(identical(other.before, before) || other.before == before)&&(identical(other.match, match) || other.match == match)&&(identical(other.after, after) || other.after == after));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,before,match,after);
}

@override
String toString() {
    return 'SessionPromptExcerpt(before: $before, match: $match, after: $after)';
}


}




// dart format on
