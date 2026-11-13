// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'command_invocation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommandInvocation {

 String get name;@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource get source; String? get arguments;
/// Create a copy of CommandInvocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandInvocationCopyWith<CommandInvocation> get copyWith => _$CommandInvocationCopyWithImpl<CommandInvocation>(this as CommandInvocation, _$identity);

  /// Serializes this CommandInvocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CommandInvocation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandInvocation&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.arguments, _this.arguments) || other.arguments == _this.arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CommandInvocation;
  return Object.hash(runtimeType,_this.name,_this.source,_this.arguments);
}

@override
String toString() {
  final _this = this as CommandInvocation;
  return 'CommandInvocation(name: ${_this.name}, source: ${_this.source}, arguments: ${_this.arguments})';
}


}

/// @nodoc
abstract mixin class $CommandInvocationCopyWith<$Res>  {
  factory $CommandInvocationCopyWith(CommandInvocation value, $Res Function(CommandInvocation) _then) = _$CommandInvocationCopyWithImpl;
@useResult
$Res call({
 String name,@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource source, String? arguments
});




}
/// @nodoc
class _$CommandInvocationCopyWithImpl<$Res>
    implements $CommandInvocationCopyWith<$Res> {
  _$CommandInvocationCopyWithImpl(this._self, this._then);

  final CommandInvocation _self;
  final $Res Function(CommandInvocation) _then;

/// Create a copy of CommandInvocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? source = null,Object? arguments = freezed,}) {
  return _then(CommandInvocation(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CommandSource,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CommandInvocation implements CommandInvocation {
  const _CommandInvocation({required this.name, @JsonKey(unknownEnumValue: CommandSource.unknown) required this.source, required this.arguments});
  factory _CommandInvocation.fromJson(Map<String, dynamic> json) => _$CommandInvocationFromJson(json);

@override final  String name;
@override@JsonKey(unknownEnumValue: CommandSource.unknown) final  CommandSource source;
@override final  String? arguments;

/// Create a copy of CommandInvocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandInvocationCopyWith<_CommandInvocation> get copyWith => __$CommandInvocationCopyWithImpl<_CommandInvocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommandInvocationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandInvocation&&(identical(other.name, name) || other.name == name)&&(identical(other.source, source) || other.source == source)&&(identical(other.arguments, arguments) || other.arguments == arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,source,arguments);
}

@override
String toString() {
    return 'CommandInvocation(name: $name, source: $source, arguments: $arguments)';
}


}

/// @nodoc
abstract mixin class _$CommandInvocationCopyWith<$Res> implements $CommandInvocationCopyWith<$Res> {
  factory _$CommandInvocationCopyWith(_CommandInvocation value, $Res Function(_CommandInvocation) _then) = __$CommandInvocationCopyWithImpl;
@override @useResult
$Res call({
 String name,@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource source, String? arguments
});




}
/// @nodoc
class __$CommandInvocationCopyWithImpl<$Res>
    implements _$CommandInvocationCopyWith<$Res> {
  __$CommandInvocationCopyWithImpl(this._self, this._then);

  final _CommandInvocation _self;
  final $Res Function(_CommandInvocation) _then;

/// Create a copy of CommandInvocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? source = null,Object? arguments = freezed,}) {
  return _then(_CommandInvocation(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CommandSource,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
