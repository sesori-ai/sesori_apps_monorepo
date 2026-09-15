// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'desktop_sidebar_layout.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DesktopSidebarLayout {

 double get width; bool get collapsed;
/// Create a copy of DesktopSidebarLayout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesktopSidebarLayoutCopyWith<DesktopSidebarLayout> get copyWith => _$DesktopSidebarLayoutCopyWithImpl<DesktopSidebarLayout>(this as DesktopSidebarLayout, _$identity);

  /// Serializes this DesktopSidebarLayout to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DesktopSidebarLayout;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopSidebarLayout&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.collapsed, _this.collapsed) || other.collapsed == _this.collapsed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DesktopSidebarLayout;
  return Object.hash(runtimeType,_this.width,_this.collapsed);
}

@override
String toString() {
  final _this = this as DesktopSidebarLayout;
  return 'DesktopSidebarLayout(width: ${_this.width}, collapsed: ${_this.collapsed})';
}


}

/// @nodoc
abstract mixin class $DesktopSidebarLayoutCopyWith<$Res>  {
  factory $DesktopSidebarLayoutCopyWith(DesktopSidebarLayout value, $Res Function(DesktopSidebarLayout) _then) = _$DesktopSidebarLayoutCopyWithImpl;
@useResult
$Res call({
 double width, bool collapsed
});




}
/// @nodoc
class _$DesktopSidebarLayoutCopyWithImpl<$Res>
    implements $DesktopSidebarLayoutCopyWith<$Res> {
  _$DesktopSidebarLayoutCopyWithImpl(this._self, this._then);

  final DesktopSidebarLayout _self;
  final $Res Function(DesktopSidebarLayout) _then;

/// Create a copy of DesktopSidebarLayout
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? collapsed = null,}) {
  return _then(DesktopSidebarLayout(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,collapsed: null == collapsed ? _self.collapsed : collapsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DesktopSidebarLayout implements DesktopSidebarLayout {
  const _DesktopSidebarLayout({this.width = 260, this.collapsed = false});
  factory _DesktopSidebarLayout.fromJson(Map<String, dynamic> json) => _$DesktopSidebarLayoutFromJson(json);

@override@JsonKey() final  double width;
@override@JsonKey() final  bool collapsed;

/// Create a copy of DesktopSidebarLayout
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesktopSidebarLayoutCopyWith<_DesktopSidebarLayout> get copyWith => __$DesktopSidebarLayoutCopyWithImpl<_DesktopSidebarLayout>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DesktopSidebarLayoutToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesktopSidebarLayout&&(identical(other.width, width) || other.width == width)&&(identical(other.collapsed, collapsed) || other.collapsed == collapsed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,width,collapsed);
}

@override
String toString() {
    return 'DesktopSidebarLayout(width: $width, collapsed: $collapsed)';
}


}

/// @nodoc
abstract mixin class _$DesktopSidebarLayoutCopyWith<$Res> implements $DesktopSidebarLayoutCopyWith<$Res> {
  factory _$DesktopSidebarLayoutCopyWith(_DesktopSidebarLayout value, $Res Function(_DesktopSidebarLayout) _then) = __$DesktopSidebarLayoutCopyWithImpl;
@override @useResult
$Res call({
 double width, bool collapsed
});




}
/// @nodoc
class __$DesktopSidebarLayoutCopyWithImpl<$Res>
    implements _$DesktopSidebarLayoutCopyWith<$Res> {
  __$DesktopSidebarLayoutCopyWithImpl(this._self, this._then);

  final _DesktopSidebarLayout _self;
  final $Res Function(_DesktopSidebarLayout) _then;

/// Create a copy of DesktopSidebarLayout
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? collapsed = null,}) {
  return _then(_DesktopSidebarLayout(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,collapsed: null == collapsed ? _self.collapsed : collapsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
