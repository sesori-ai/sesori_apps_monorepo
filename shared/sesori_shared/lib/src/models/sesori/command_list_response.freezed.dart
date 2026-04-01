// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'command_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommandListResponse {

 List<CommandInfo> get items;
/// Create a copy of CommandListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandListResponseCopyWith<CommandListResponse> get copyWith => _$CommandListResponseCopyWithImpl<CommandListResponse>(this as CommandListResponse, _$identity);

  /// Serializes this CommandListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandListResponse&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'CommandListResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class $CommandListResponseCopyWith<$Res>  {
  factory $CommandListResponseCopyWith(CommandListResponse value, $Res Function(CommandListResponse) _then) = _$CommandListResponseCopyWithImpl;
@useResult
$Res call({
 List<CommandInfo> items
});




}
/// @nodoc
class _$CommandListResponseCopyWithImpl<$Res>
    implements $CommandListResponseCopyWith<$Res> {
  _$CommandListResponseCopyWithImpl(this._self, this._then);

  final CommandListResponse _self;
  final $Res Function(CommandListResponse) _then;

/// Create a copy of CommandListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<CommandInfo>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CommandListResponse implements CommandListResponse {
  const _CommandListResponse({required final  List<CommandInfo> items}): _items = items;
  factory _CommandListResponse.fromJson(Map<String, dynamic> json) => _$CommandListResponseFromJson(json);

 final  List<CommandInfo> _items;
@override List<CommandInfo> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of CommandListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandListResponseCopyWith<_CommandListResponse> get copyWith => __$CommandListResponseCopyWithImpl<_CommandListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommandListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandListResponse&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'CommandListResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class _$CommandListResponseCopyWith<$Res> implements $CommandListResponseCopyWith<$Res> {
  factory _$CommandListResponseCopyWith(_CommandListResponse value, $Res Function(_CommandListResponse) _then) = __$CommandListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<CommandInfo> items
});




}
/// @nodoc
class __$CommandListResponseCopyWithImpl<$Res>
    implements _$CommandListResponseCopyWith<$Res> {
  __$CommandListResponseCopyWithImpl(this._self, this._then);

  final _CommandListResponse _self;
  final $Res Function(_CommandListResponse) _then;

/// Create a copy of CommandListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_CommandListResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<CommandInfo>,
  ));
}


}

// dart format on
