// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_variant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionVariant {

 String get id;
/// Create a copy of SessionVariant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionVariantCopyWith<SessionVariant> get copyWith => _$SessionVariantCopyWithImpl<SessionVariant>(this as SessionVariant, _$identity);

  /// Serializes this SessionVariant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionVariant&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'SessionVariant(id: $id)';
}


}

/// @nodoc
abstract mixin class $SessionVariantCopyWith<$Res>  {
  factory $SessionVariantCopyWith(SessionVariant value, $Res Function(SessionVariant) _then) = _$SessionVariantCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$SessionVariantCopyWithImpl<$Res>
    implements $SessionVariantCopyWith<$Res> {
  _$SessionVariantCopyWithImpl(this._self, this._then);

  final SessionVariant _self;
  final $Res Function(SessionVariant) _then;

/// Create a copy of SessionVariant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionVariant implements SessionVariant {
  const _SessionVariant({required this.id});
  factory _SessionVariant.fromJson(Map<String, dynamic> json) => _$SessionVariantFromJson(json);

@override final  String id;

/// Create a copy of SessionVariant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionVariantCopyWith<_SessionVariant> get copyWith => __$SessionVariantCopyWithImpl<_SessionVariant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionVariantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionVariant&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'SessionVariant(id: $id)';
}


}

/// @nodoc
abstract mixin class _$SessionVariantCopyWith<$Res> implements $SessionVariantCopyWith<$Res> {
  factory _$SessionVariantCopyWith(_SessionVariant value, $Res Function(_SessionVariant) _then) = __$SessionVariantCopyWithImpl;
@override @useResult
$Res call({
 String id
});




}
/// @nodoc
class __$SessionVariantCopyWithImpl<$Res>
    implements _$SessionVariantCopyWith<$Res> {
  __$SessionVariantCopyWithImpl(this._self, this._then);

  final _SessionVariant _self;
  final $Res Function(_SessionVariant) _then;

/// Create a copy of SessionVariant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_SessionVariant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
