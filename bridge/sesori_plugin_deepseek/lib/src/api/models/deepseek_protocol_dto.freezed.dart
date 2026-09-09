// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'deepseek_protocol_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
DeepSeekSessionStopRequestDto _$DeepSeekSessionStopRequestDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'session':
          return DeepSeekSessionStopSessionRequestDto.fromJson(
            json
          );
                case 'child':
          return DeepSeekSessionStopChildRequestDto.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'DeepSeekSessionStopRequestDto',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$DeepSeekSessionStopRequestDto {

 String get sessionId;
/// Create a copy of DeepSeekSessionStopRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeepSeekSessionStopRequestDtoCopyWith<DeepSeekSessionStopRequestDto> get copyWith => _$DeepSeekSessionStopRequestDtoCopyWithImpl<DeepSeekSessionStopRequestDto>(this as DeepSeekSessionStopRequestDto, _$identity);

  /// Serializes this DeepSeekSessionStopRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeepSeekSessionStopRequestDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'DeepSeekSessionStopRequestDto(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $DeepSeekSessionStopRequestDtoCopyWith<$Res>  {
  factory $DeepSeekSessionStopRequestDtoCopyWith(DeepSeekSessionStopRequestDto value, $Res Function(DeepSeekSessionStopRequestDto) _then) = _$DeepSeekSessionStopRequestDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$DeepSeekSessionStopRequestDtoCopyWithImpl<$Res>
    implements $DeepSeekSessionStopRequestDtoCopyWith<$Res> {
  _$DeepSeekSessionStopRequestDtoCopyWithImpl(this._self, this._then);

  final DeepSeekSessionStopRequestDto _self;
  final $Res Function(DeepSeekSessionStopRequestDto) _then;

/// Create a copy of DeepSeekSessionStopRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeepSeekSessionStopRequestDto].
extension DeepSeekSessionStopRequestDtoPatterns on DeepSeekSessionStopRequestDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DeepSeekSessionStopSessionRequestDto value)?  session,TResult Function( DeepSeekSessionStopChildRequestDto value)?  child,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DeepSeekSessionStopSessionRequestDto() when session != null:
return session(_that);case DeepSeekSessionStopChildRequestDto() when child != null:
return child(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DeepSeekSessionStopSessionRequestDto value)  session,required TResult Function( DeepSeekSessionStopChildRequestDto value)  child,}){
final _that = this;
switch (_that) {
case DeepSeekSessionStopSessionRequestDto():
return session(_that);case DeepSeekSessionStopChildRequestDto():
return child(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DeepSeekSessionStopSessionRequestDto value)?  session,TResult? Function( DeepSeekSessionStopChildRequestDto value)?  child,}){
final _that = this;
switch (_that) {
case DeepSeekSessionStopSessionRequestDto() when session != null:
return session(_that);case DeepSeekSessionStopChildRequestDto() when child != null:
return child(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String sessionId)?  session,TResult Function( String sessionId,  String childSessionId)?  child,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DeepSeekSessionStopSessionRequestDto() when session != null:
return session(_that.sessionId);case DeepSeekSessionStopChildRequestDto() when child != null:
return child(_that.sessionId,_that.childSessionId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String sessionId)  session,required TResult Function( String sessionId,  String childSessionId)  child,}) {final _that = this;
switch (_that) {
case DeepSeekSessionStopSessionRequestDto():
return session(_that.sessionId);case DeepSeekSessionStopChildRequestDto():
return child(_that.sessionId,_that.childSessionId);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String sessionId)?  session,TResult? Function( String sessionId,  String childSessionId)?  child,}) {final _that = this;
switch (_that) {
case DeepSeekSessionStopSessionRequestDto() when session != null:
return session(_that.sessionId);case DeepSeekSessionStopChildRequestDto() when child != null:
return child(_that.sessionId,_that.childSessionId);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(disallowUnrecognizedKeys: true)
class DeepSeekSessionStopSessionRequestDto implements DeepSeekSessionStopRequestDto {
  const DeepSeekSessionStopSessionRequestDto({required this.sessionId,  String? $type}): $type = $type ?? 'session';
  factory DeepSeekSessionStopSessionRequestDto.fromJson(Map<String, dynamic> json) => _$DeepSeekSessionStopSessionRequestDtoFromJson(json);

@override final  String sessionId;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of DeepSeekSessionStopRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeepSeekSessionStopSessionRequestDtoCopyWith<DeepSeekSessionStopSessionRequestDto> get copyWith => _$DeepSeekSessionStopSessionRequestDtoCopyWithImpl<DeepSeekSessionStopSessionRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeepSeekSessionStopSessionRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeepSeekSessionStopSessionRequestDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'DeepSeekSessionStopRequestDto.session(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $DeepSeekSessionStopSessionRequestDtoCopyWith<$Res> implements $DeepSeekSessionStopRequestDtoCopyWith<$Res> {
  factory $DeepSeekSessionStopSessionRequestDtoCopyWith(DeepSeekSessionStopSessionRequestDto value, $Res Function(DeepSeekSessionStopSessionRequestDto) _then) = _$DeepSeekSessionStopSessionRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$DeepSeekSessionStopSessionRequestDtoCopyWithImpl<$Res>
    implements $DeepSeekSessionStopSessionRequestDtoCopyWith<$Res> {
  _$DeepSeekSessionStopSessionRequestDtoCopyWithImpl(this._self, this._then);

  final DeepSeekSessionStopSessionRequestDto _self;
  final $Res Function(DeepSeekSessionStopSessionRequestDto) _then;

/// Create a copy of DeepSeekSessionStopRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(DeepSeekSessionStopSessionRequestDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc

@JsonSerializable(disallowUnrecognizedKeys: true)
class DeepSeekSessionStopChildRequestDto implements DeepSeekSessionStopRequestDto {
  const DeepSeekSessionStopChildRequestDto({required this.sessionId, required this.childSessionId,  String? $type}): $type = $type ?? 'child';
  factory DeepSeekSessionStopChildRequestDto.fromJson(Map<String, dynamic> json) => _$DeepSeekSessionStopChildRequestDtoFromJson(json);

@override final  String sessionId;
 final  String childSessionId;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of DeepSeekSessionStopRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeepSeekSessionStopChildRequestDtoCopyWith<DeepSeekSessionStopChildRequestDto> get copyWith => _$DeepSeekSessionStopChildRequestDtoCopyWithImpl<DeepSeekSessionStopChildRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeepSeekSessionStopChildRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeepSeekSessionStopChildRequestDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.childSessionId, childSessionId) || other.childSessionId == childSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,childSessionId);

@override
String toString() {
  return 'DeepSeekSessionStopRequestDto.child(sessionId: $sessionId, childSessionId: $childSessionId)';
}


}

/// @nodoc
abstract mixin class $DeepSeekSessionStopChildRequestDtoCopyWith<$Res> implements $DeepSeekSessionStopRequestDtoCopyWith<$Res> {
  factory $DeepSeekSessionStopChildRequestDtoCopyWith(DeepSeekSessionStopChildRequestDto value, $Res Function(DeepSeekSessionStopChildRequestDto) _then) = _$DeepSeekSessionStopChildRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String childSessionId
});




}
/// @nodoc
class _$DeepSeekSessionStopChildRequestDtoCopyWithImpl<$Res>
    implements $DeepSeekSessionStopChildRequestDtoCopyWith<$Res> {
  _$DeepSeekSessionStopChildRequestDtoCopyWithImpl(this._self, this._then);

  final DeepSeekSessionStopChildRequestDto _self;
  final $Res Function(DeepSeekSessionStopChildRequestDto) _then;

/// Create a copy of DeepSeekSessionStopRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? childSessionId = null,}) {
  return _then(DeepSeekSessionStopChildRequestDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,childSessionId: null == childSessionId ? _self.childSessionId : childSessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
