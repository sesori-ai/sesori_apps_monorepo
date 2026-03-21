// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'send_prompt_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SendPromptRequest {

 List<PromptPart> get parts; String? get agent; PromptModel? get model;
/// Create a copy of SendPromptRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendPromptRequestCopyWith<SendPromptRequest> get copyWith => _$SendPromptRequestCopyWithImpl<SendPromptRequest>(this as SendPromptRequest, _$identity);

  /// Serializes this SendPromptRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendPromptRequest&&const DeepCollectionEquality().equals(other.parts, parts)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(parts),agent,model);

@override
String toString() {
  return 'SendPromptRequest(parts: $parts, agent: $agent, model: $model)';
}


}

/// @nodoc
abstract mixin class $SendPromptRequestCopyWith<$Res>  {
  factory $SendPromptRequestCopyWith(SendPromptRequest value, $Res Function(SendPromptRequest) _then) = _$SendPromptRequestCopyWithImpl;
@useResult
$Res call({
 List<PromptPart> parts, String? agent, PromptModel? model
});


$PromptModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$SendPromptRequestCopyWithImpl<$Res>
    implements $SendPromptRequestCopyWith<$Res> {
  _$SendPromptRequestCopyWithImpl(this._self, this._then);

  final SendPromptRequest _self;
  final $Res Function(SendPromptRequest) _then;

/// Create a copy of SendPromptRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? parts = null,Object? agent = freezed,Object? model = freezed,}) {
  return _then(_self.copyWith(
parts: null == parts ? _self.parts : parts // ignore: cast_nullable_to_non_nullable
as List<PromptPart>,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PromptModel?,
  ));
}
/// Create a copy of SendPromptRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PromptModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _SendPromptRequest implements SendPromptRequest {
  const _SendPromptRequest({required final  List<PromptPart> parts, this.agent, this.model}): _parts = parts;
  factory _SendPromptRequest.fromJson(Map<String, dynamic> json) => _$SendPromptRequestFromJson(json);

 final  List<PromptPart> _parts;
@override List<PromptPart> get parts {
  if (_parts is EqualUnmodifiableListView) return _parts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parts);
}

@override final  String? agent;
@override final  PromptModel? model;

/// Create a copy of SendPromptRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SendPromptRequestCopyWith<_SendPromptRequest> get copyWith => __$SendPromptRequestCopyWithImpl<_SendPromptRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SendPromptRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SendPromptRequest&&const DeepCollectionEquality().equals(other._parts, _parts)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_parts),agent,model);

@override
String toString() {
  return 'SendPromptRequest(parts: $parts, agent: $agent, model: $model)';
}


}

/// @nodoc
abstract mixin class _$SendPromptRequestCopyWith<$Res> implements $SendPromptRequestCopyWith<$Res> {
  factory _$SendPromptRequestCopyWith(_SendPromptRequest value, $Res Function(_SendPromptRequest) _then) = __$SendPromptRequestCopyWithImpl;
@override @useResult
$Res call({
 List<PromptPart> parts, String? agent, PromptModel? model
});


@override $PromptModelCopyWith<$Res>? get model;

}
/// @nodoc
class __$SendPromptRequestCopyWithImpl<$Res>
    implements _$SendPromptRequestCopyWith<$Res> {
  __$SendPromptRequestCopyWithImpl(this._self, this._then);

  final _SendPromptRequest _self;
  final $Res Function(_SendPromptRequest) _then;

/// Create a copy of SendPromptRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? parts = null,Object? agent = freezed,Object? model = freezed,}) {
  return _then(_SendPromptRequest(
parts: null == parts ? _self._parts : parts // ignore: cast_nullable_to_non_nullable
as List<PromptPart>,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PromptModel?,
  ));
}

/// Create a copy of SendPromptRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PromptModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// @nodoc
mixin _$PromptPart {

 String get type; String? get text;
/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptPartCopyWith<PromptPart> get copyWith => _$PromptPartCopyWithImpl<PromptPart>(this as PromptPart, _$identity);

  /// Serializes this PromptPart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptPart&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text);

@override
String toString() {
  return 'PromptPart(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class $PromptPartCopyWith<$Res>  {
  factory $PromptPartCopyWith(PromptPart value, $Res Function(PromptPart) _then) = _$PromptPartCopyWithImpl;
@useResult
$Res call({
 String type, String? text
});




}
/// @nodoc
class _$PromptPartCopyWithImpl<$Res>
    implements $PromptPartCopyWith<$Res> {
  _$PromptPartCopyWithImpl(this._self, this._then);

  final PromptPart _self;
  final $Res Function(PromptPart) _then;

/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? text = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PromptPart implements PromptPart {
  const _PromptPart({required this.type, this.text});
  factory _PromptPart.fromJson(Map<String, dynamic> json) => _$PromptPartFromJson(json);

@override final  String type;
@override final  String? text;

/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PromptPartCopyWith<_PromptPart> get copyWith => __$PromptPartCopyWithImpl<_PromptPart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromptPartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PromptPart&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text);

@override
String toString() {
  return 'PromptPart(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class _$PromptPartCopyWith<$Res> implements $PromptPartCopyWith<$Res> {
  factory _$PromptPartCopyWith(_PromptPart value, $Res Function(_PromptPart) _then) = __$PromptPartCopyWithImpl;
@override @useResult
$Res call({
 String type, String? text
});




}
/// @nodoc
class __$PromptPartCopyWithImpl<$Res>
    implements _$PromptPartCopyWith<$Res> {
  __$PromptPartCopyWithImpl(this._self, this._then);

  final _PromptPart _self;
  final $Res Function(_PromptPart) _then;

/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? text = freezed,}) {
  return _then(_PromptPart(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PromptModel {

 String get providerID; String get modelID;
/// Create a copy of PromptModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptModelCopyWith<PromptModel> get copyWith => _$PromptModelCopyWithImpl<PromptModel>(this as PromptModel, _$identity);

  /// Serializes this PromptModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptModel&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.modelID, modelID) || other.modelID == modelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,providerID,modelID);

@override
String toString() {
  return 'PromptModel(providerID: $providerID, modelID: $modelID)';
}


}

/// @nodoc
abstract mixin class $PromptModelCopyWith<$Res>  {
  factory $PromptModelCopyWith(PromptModel value, $Res Function(PromptModel) _then) = _$PromptModelCopyWithImpl;
@useResult
$Res call({
 String providerID, String modelID
});




}
/// @nodoc
class _$PromptModelCopyWithImpl<$Res>
    implements $PromptModelCopyWith<$Res> {
  _$PromptModelCopyWithImpl(this._self, this._then);

  final PromptModel _self;
  final $Res Function(PromptModel) _then;

/// Create a copy of PromptModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providerID = null,Object? modelID = null,}) {
  return _then(_self.copyWith(
providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,modelID: null == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PromptModel implements PromptModel {
  const _PromptModel({required this.providerID, required this.modelID});
  factory _PromptModel.fromJson(Map<String, dynamic> json) => _$PromptModelFromJson(json);

@override final  String providerID;
@override final  String modelID;

/// Create a copy of PromptModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PromptModelCopyWith<_PromptModel> get copyWith => __$PromptModelCopyWithImpl<_PromptModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromptModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PromptModel&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.modelID, modelID) || other.modelID == modelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,providerID,modelID);

@override
String toString() {
  return 'PromptModel(providerID: $providerID, modelID: $modelID)';
}


}

/// @nodoc
abstract mixin class _$PromptModelCopyWith<$Res> implements $PromptModelCopyWith<$Res> {
  factory _$PromptModelCopyWith(_PromptModel value, $Res Function(_PromptModel) _then) = __$PromptModelCopyWithImpl;
@override @useResult
$Res call({
 String providerID, String modelID
});




}
/// @nodoc
class __$PromptModelCopyWithImpl<$Res>
    implements _$PromptModelCopyWith<$Res> {
  __$PromptModelCopyWithImpl(this._self, this._then);

  final _PromptModel _self;
  final $Res Function(_PromptModel) _then;

/// Create a copy of PromptModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providerID = null,Object? modelID = null,}) {
  return _then(_PromptModel(
providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,modelID: null == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
