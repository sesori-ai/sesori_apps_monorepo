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
  const _SendPromptRequest({required final  List<PromptPart> parts, required this.agent, required this.model}): _parts = parts;
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

PromptPart _$PromptPartFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return PromptPartText.fromJson(
            json
          );
                case 'file_path':
          return PromptPartFilePath.fromJson(
            json
          );
                case 'file_url':
          return PromptPartFileUrl.fromJson(
            json
          );
                case 'file_data':
          return PromptPartFileData.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'PromptPart',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$PromptPart {



  /// Serializes this PromptPart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptPart);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PromptPart()';
}


}

/// @nodoc
class $PromptPartCopyWith<$Res>  {
$PromptPartCopyWith(PromptPart _, $Res Function(PromptPart) __);
}



/// @nodoc
@JsonSerializable()

class PromptPartText implements PromptPart {
  const PromptPartText({required this.text, final  String? $type}): $type = $type ?? 'text';
  factory PromptPartText.fromJson(Map<String, dynamic> json) => _$PromptPartTextFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptPartTextCopyWith<PromptPartText> get copyWith => _$PromptPartTextCopyWithImpl<PromptPartText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromptPartTextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptPartText&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'PromptPart.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $PromptPartTextCopyWith<$Res> implements $PromptPartCopyWith<$Res> {
  factory $PromptPartTextCopyWith(PromptPartText value, $Res Function(PromptPartText) _then) = _$PromptPartTextCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$PromptPartTextCopyWithImpl<$Res>
    implements $PromptPartTextCopyWith<$Res> {
  _$PromptPartTextCopyWithImpl(this._self, this._then);

  final PromptPartText _self;
  final $Res Function(PromptPartText) _then;

/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(PromptPartText(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class PromptPartFilePath implements PromptPart {
  const PromptPartFilePath({required this.mime, required this.path, required this.filename, final  String? $type}): $type = $type ?? 'file_path';
  factory PromptPartFilePath.fromJson(Map<String, dynamic> json) => _$PromptPartFilePathFromJson(json);

 final  String mime;
 final  String path;
 final  String? filename;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptPartFilePathCopyWith<PromptPartFilePath> get copyWith => _$PromptPartFilePathCopyWithImpl<PromptPartFilePath>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromptPartFilePathToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptPartFilePath&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.path, path) || other.path == path)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,path,filename);

@override
String toString() {
  return 'PromptPart.filePath(mime: $mime, path: $path, filename: $filename)';
}


}

/// @nodoc
abstract mixin class $PromptPartFilePathCopyWith<$Res> implements $PromptPartCopyWith<$Res> {
  factory $PromptPartFilePathCopyWith(PromptPartFilePath value, $Res Function(PromptPartFilePath) _then) = _$PromptPartFilePathCopyWithImpl;
@useResult
$Res call({
 String mime, String path, String? filename
});




}
/// @nodoc
class _$PromptPartFilePathCopyWithImpl<$Res>
    implements $PromptPartFilePathCopyWith<$Res> {
  _$PromptPartFilePathCopyWithImpl(this._self, this._then);

  final PromptPartFilePath _self;
  final $Res Function(PromptPartFilePath) _then;

/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? path = null,Object? filename = freezed,}) {
  return _then(PromptPartFilePath(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class PromptPartFileUrl implements PromptPart {
  const PromptPartFileUrl({required this.mime, required this.url, required this.filename, final  String? $type}): $type = $type ?? 'file_url';
  factory PromptPartFileUrl.fromJson(Map<String, dynamic> json) => _$PromptPartFileUrlFromJson(json);

 final  String mime;
 final  String url;
 final  String? filename;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptPartFileUrlCopyWith<PromptPartFileUrl> get copyWith => _$PromptPartFileUrlCopyWithImpl<PromptPartFileUrl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromptPartFileUrlToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptPartFileUrl&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.url, url) || other.url == url)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,url,filename);

@override
String toString() {
  return 'PromptPart.fileUrl(mime: $mime, url: $url, filename: $filename)';
}


}

/// @nodoc
abstract mixin class $PromptPartFileUrlCopyWith<$Res> implements $PromptPartCopyWith<$Res> {
  factory $PromptPartFileUrlCopyWith(PromptPartFileUrl value, $Res Function(PromptPartFileUrl) _then) = _$PromptPartFileUrlCopyWithImpl;
@useResult
$Res call({
 String mime, String url, String? filename
});




}
/// @nodoc
class _$PromptPartFileUrlCopyWithImpl<$Res>
    implements $PromptPartFileUrlCopyWith<$Res> {
  _$PromptPartFileUrlCopyWithImpl(this._self, this._then);

  final PromptPartFileUrl _self;
  final $Res Function(PromptPartFileUrl) _then;

/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? url = null,Object? filename = freezed,}) {
  return _then(PromptPartFileUrl(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class PromptPartFileData implements PromptPart {
  const PromptPartFileData({required this.mime, required this.base64, required this.filename, final  String? $type}): $type = $type ?? 'file_data';
  factory PromptPartFileData.fromJson(Map<String, dynamic> json) => _$PromptPartFileDataFromJson(json);

 final  String mime;
 final  String base64;
 final  String? filename;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptPartFileDataCopyWith<PromptPartFileData> get copyWith => _$PromptPartFileDataCopyWithImpl<PromptPartFileData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromptPartFileDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptPartFileData&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,base64,filename);

@override
String toString() {
  return 'PromptPart.fileData(mime: $mime, base64: $base64, filename: $filename)';
}


}

/// @nodoc
abstract mixin class $PromptPartFileDataCopyWith<$Res> implements $PromptPartCopyWith<$Res> {
  factory $PromptPartFileDataCopyWith(PromptPartFileData value, $Res Function(PromptPartFileData) _then) = _$PromptPartFileDataCopyWithImpl;
@useResult
$Res call({
 String mime, String base64, String? filename
});




}
/// @nodoc
class _$PromptPartFileDataCopyWithImpl<$Res>
    implements $PromptPartFileDataCopyWith<$Res> {
  _$PromptPartFileDataCopyWithImpl(this._self, this._then);

  final PromptPartFileData _self;
  final $Res Function(PromptPartFileData) _then;

/// Create a copy of PromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? base64 = null,Object? filename = freezed,}) {
  return _then(PromptPartFileData(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,base64: null == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
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
