// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_model_provider_error_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
CodexModelProviderErrorDto _$CodexModelProviderErrorDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'modelProviderMismatch':
          return CodexModelProviderMismatchDto.fromJson(
            json
          );
                case 'modelProviderNotConfigured':
          return CodexModelProviderNotConfiguredDto.fromJson(
            json
          );
                case 'modelProviderPolicyConflict':
          return CodexModelProviderPolicyConflictDto.fromJson(
            json
          );
        
          default:
            return CodexUnknownModelProviderErrorDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexModelProviderErrorDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelProviderErrorDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CodexModelProviderErrorDto()';
}


}

/// @nodoc
class $CodexModelProviderErrorDtoCopyWith<$Res>  {
$CodexModelProviderErrorDtoCopyWith(CodexModelProviderErrorDto _, $Res Function(CodexModelProviderErrorDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexModelProviderMismatchDto implements CodexModelProviderErrorDto {
  const CodexModelProviderMismatchDto({required this.modelProvider, required this.currentModelProvider,  String? $type}): $type = $type ?? 'modelProviderMismatch';
  factory CodexModelProviderMismatchDto.fromJson(Map<String, dynamic> json) => _$CodexModelProviderMismatchDtoFromJson(json);

 final  String modelProvider;
 final  String currentModelProvider;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexModelProviderErrorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelProviderMismatchDtoCopyWith<CodexModelProviderMismatchDto> get copyWith => _$CodexModelProviderMismatchDtoCopyWithImpl<CodexModelProviderMismatchDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelProviderMismatchDto&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.currentModelProvider, currentModelProvider) || other.currentModelProvider == currentModelProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,modelProvider,currentModelProvider);
}

@override
String toString() {
    return 'CodexModelProviderErrorDto.mismatch(modelProvider: $modelProvider, currentModelProvider: $currentModelProvider)';
}


}

/// @nodoc
abstract mixin class $CodexModelProviderMismatchDtoCopyWith<$Res> implements $CodexModelProviderErrorDtoCopyWith<$Res> {
  factory $CodexModelProviderMismatchDtoCopyWith(CodexModelProviderMismatchDto value, $Res Function(CodexModelProviderMismatchDto) _then) = _$CodexModelProviderMismatchDtoCopyWithImpl;
@useResult
$Res call({
 String modelProvider, String currentModelProvider
});




}
/// @nodoc
class _$CodexModelProviderMismatchDtoCopyWithImpl<$Res>
    implements $CodexModelProviderMismatchDtoCopyWith<$Res> {
  _$CodexModelProviderMismatchDtoCopyWithImpl(this._self, this._then);

  final CodexModelProviderMismatchDto _self;
  final $Res Function(CodexModelProviderMismatchDto) _then;

/// Create a copy of CodexModelProviderErrorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? modelProvider = null,Object? currentModelProvider = null,}) {
  return _then(CodexModelProviderMismatchDto(
modelProvider: null == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String,currentModelProvider: null == currentModelProvider ? _self.currentModelProvider : currentModelProvider // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexModelProviderNotConfiguredDto implements CodexModelProviderErrorDto {
  const CodexModelProviderNotConfiguredDto({required this.modelProvider,  String? $type}): $type = $type ?? 'modelProviderNotConfigured';
  factory CodexModelProviderNotConfiguredDto.fromJson(Map<String, dynamic> json) => _$CodexModelProviderNotConfiguredDtoFromJson(json);

 final  String modelProvider;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexModelProviderErrorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelProviderNotConfiguredDtoCopyWith<CodexModelProviderNotConfiguredDto> get copyWith => _$CodexModelProviderNotConfiguredDtoCopyWithImpl<CodexModelProviderNotConfiguredDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelProviderNotConfiguredDto&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,modelProvider);
}

@override
String toString() {
    return 'CodexModelProviderErrorDto.notConfigured(modelProvider: $modelProvider)';
}


}

/// @nodoc
abstract mixin class $CodexModelProviderNotConfiguredDtoCopyWith<$Res> implements $CodexModelProviderErrorDtoCopyWith<$Res> {
  factory $CodexModelProviderNotConfiguredDtoCopyWith(CodexModelProviderNotConfiguredDto value, $Res Function(CodexModelProviderNotConfiguredDto) _then) = _$CodexModelProviderNotConfiguredDtoCopyWithImpl;
@useResult
$Res call({
 String modelProvider
});




}
/// @nodoc
class _$CodexModelProviderNotConfiguredDtoCopyWithImpl<$Res>
    implements $CodexModelProviderNotConfiguredDtoCopyWith<$Res> {
  _$CodexModelProviderNotConfiguredDtoCopyWithImpl(this._self, this._then);

  final CodexModelProviderNotConfiguredDto _self;
  final $Res Function(CodexModelProviderNotConfiguredDto) _then;

/// Create a copy of CodexModelProviderErrorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? modelProvider = null,}) {
  return _then(CodexModelProviderNotConfiguredDto(
modelProvider: null == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexModelProviderPolicyConflictDto implements CodexModelProviderErrorDto {
  const CodexModelProviderPolicyConflictDto({required this.modelProvider, required this.requiredModelProvider,  String? $type}): $type = $type ?? 'modelProviderPolicyConflict';
  factory CodexModelProviderPolicyConflictDto.fromJson(Map<String, dynamic> json) => _$CodexModelProviderPolicyConflictDtoFromJson(json);

 final  String modelProvider;
 final  String requiredModelProvider;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexModelProviderErrorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexModelProviderPolicyConflictDtoCopyWith<CodexModelProviderPolicyConflictDto> get copyWith => _$CodexModelProviderPolicyConflictDtoCopyWithImpl<CodexModelProviderPolicyConflictDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexModelProviderPolicyConflictDto&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.requiredModelProvider, requiredModelProvider) || other.requiredModelProvider == requiredModelProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,modelProvider,requiredModelProvider);
}

@override
String toString() {
    return 'CodexModelProviderErrorDto.policyConflict(modelProvider: $modelProvider, requiredModelProvider: $requiredModelProvider)';
}


}

/// @nodoc
abstract mixin class $CodexModelProviderPolicyConflictDtoCopyWith<$Res> implements $CodexModelProviderErrorDtoCopyWith<$Res> {
  factory $CodexModelProviderPolicyConflictDtoCopyWith(CodexModelProviderPolicyConflictDto value, $Res Function(CodexModelProviderPolicyConflictDto) _then) = _$CodexModelProviderPolicyConflictDtoCopyWithImpl;
@useResult
$Res call({
 String modelProvider, String requiredModelProvider
});




}
/// @nodoc
class _$CodexModelProviderPolicyConflictDtoCopyWithImpl<$Res>
    implements $CodexModelProviderPolicyConflictDtoCopyWith<$Res> {
  _$CodexModelProviderPolicyConflictDtoCopyWithImpl(this._self, this._then);

  final CodexModelProviderPolicyConflictDto _self;
  final $Res Function(CodexModelProviderPolicyConflictDto) _then;

/// Create a copy of CodexModelProviderErrorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? modelProvider = null,Object? requiredModelProvider = null,}) {
  return _then(CodexModelProviderPolicyConflictDto(
modelProvider: null == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String,requiredModelProvider: null == requiredModelProvider ? _self.requiredModelProvider : requiredModelProvider // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexUnknownModelProviderErrorDto implements CodexModelProviderErrorDto {
  const CodexUnknownModelProviderErrorDto({ String? $type}): $type = $type ?? 'unknown';
  factory CodexUnknownModelProviderErrorDto.fromJson(Map<String, dynamic> json) => _$CodexUnknownModelProviderErrorDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexUnknownModelProviderErrorDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CodexModelProviderErrorDto.unknown()';
}


}




// dart format on
