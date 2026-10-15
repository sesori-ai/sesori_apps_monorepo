// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'form_value.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
FormValue _$FormValueFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return FormTextValue.fromJson(
            json
          );
                case 'integer':
          return FormIntegerValue.fromJson(
            json
          );
                case 'number':
          return FormNumberValue.fromJson(
            json
          );
                case 'boolean':
          return FormBooleanValue.fromJson(
            json
          );
                case 'choice':
          return FormChoiceValue.fromJson(
            json
          );
                case 'choices':
          return FormChoicesValue.fromJson(
            json
          );
        
          default:
            return FormValueUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$FormValue {



  /// Serializes this FormValue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormValue);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
@JsonSerializable()

class FormValueUnknown implements FormValue {
  const FormValueUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory FormValueUnknown.fromJson(Map<String, dynamic> json) => _$FormValueUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormValueUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormValueUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class FormTextValue implements FormValue {
  const FormTextValue({required this.value,  String? $type}): $type = $type ?? 'text';
  factory FormTextValue.fromJson(Map<String, dynamic> json) => _$FormTextValueFromJson(json);

 final  String value;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormTextValueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormTextValue&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value);
}



}




/// @nodoc
@JsonSerializable()

class FormIntegerValue implements FormValue {
  const FormIntegerValue({@FormIntegerConverter() required this.value,  String? $type}): $type = $type ?? 'integer';
  factory FormIntegerValue.fromJson(Map<String, dynamic> json) => _$FormIntegerValueFromJson(json);

@FormIntegerConverter() final  int value;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormIntegerValueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormIntegerValue&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value);
}



}




/// @nodoc
@JsonSerializable()

class FormNumberValue implements FormValue {
  const FormNumberValue({@FiniteFormNumberConverter() required this.value,  String? $type}): $type = $type ?? 'number';
  factory FormNumberValue.fromJson(Map<String, dynamic> json) => _$FormNumberValueFromJson(json);

@FiniteFormNumberConverter() final  double value;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormNumberValueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormNumberValue&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value);
}



}




/// @nodoc
@JsonSerializable()

class FormBooleanValue implements FormValue {
  const FormBooleanValue({required this.value,  String? $type}): $type = $type ?? 'boolean';
  factory FormBooleanValue.fromJson(Map<String, dynamic> json) => _$FormBooleanValueFromJson(json);

 final  bool value;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormBooleanValueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormBooleanValue&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value);
}



}




/// @nodoc
@JsonSerializable()

class FormChoiceValue implements FormValue {
  const FormChoiceValue({required this.optionId,  String? $type}): $type = $type ?? 'choice';
  factory FormChoiceValue.fromJson(Map<String, dynamic> json) => _$FormChoiceValueFromJson(json);

 final  String optionId;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormChoiceValueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormChoiceValue&&(identical(other.optionId, optionId) || other.optionId == optionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,optionId);
}



}




/// @nodoc
@JsonSerializable()

class FormChoicesValue implements FormValue {
  const FormChoicesValue({required  List<String> optionIds,  String? $type}): _optionIds = optionIds,$type = $type ?? 'choices';
  factory FormChoicesValue.fromJson(Map<String, dynamic> json) => _$FormChoicesValueFromJson(json);

 final  List<String> _optionIds;
 List<String> get optionIds {
  if (_optionIds is EqualUnmodifiableListView) return _optionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_optionIds);
}


@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormChoicesValueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormChoicesValue&&const DeepCollectionEquality().equals(other.optionIds, _optionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_optionIds));
}



}




// dart format on
