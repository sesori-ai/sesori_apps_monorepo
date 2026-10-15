// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'form_field.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FormChoice {

 String get id; String get label;

  /// Serializes this FormChoice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FormChoice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FormChoice&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.label, _this.label) || other.label == _this.label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FormChoice;
  return Object.hash(runtimeType,_this.id,_this.label);
}



}





/// @nodoc
@JsonSerializable()

class _FormChoice implements FormChoice {
  const _FormChoice({required this.id, required this.label});
  factory _FormChoice.fromJson(Map<String, dynamic> json) => _$FormChoiceFromJson(json);

@override final  String id;
@override final  String label;


@override
Map<String, dynamic> toJson() {
  return _$FormChoiceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FormChoice&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,label);
}



}





/// @nodoc
mixin _$PendingFormField {

 String get id; String get label; String? get description; bool get isRequired; FormFieldSchema get schema;

  /// Serializes this PendingFormField to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PendingFormField;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingFormField&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.isRequired, _this.isRequired) || other.isRequired == _this.isRequired)&&(identical(other.schema, _this.schema) || other.schema == _this.schema));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PendingFormField;
  return Object.hash(runtimeType,_this.id,_this.label,_this.description,_this.isRequired,_this.schema);
}



}





/// @nodoc
@JsonSerializable()

class _PendingFormField implements PendingFormField {
  const _PendingFormField({required this.id, required this.label, required this.description, required this.isRequired, required this.schema});
  factory _PendingFormField.fromJson(Map<String, dynamic> json) => _$PendingFormFieldFromJson(json);

@override final  String id;
@override final  String label;
@override final  String? description;
@override final  bool isRequired;
@override final  FormFieldSchema schema;


@override
Map<String, dynamic> toJson() {
  return _$PendingFormFieldToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingFormField&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&(identical(other.schema, schema) || other.schema == schema));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,label,description,isRequired,schema);
}



}




FormFieldSchema _$FormFieldSchemaFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return FormTextSchema.fromJson(
            json
          );
                case 'integer':
          return FormIntegerSchema.fromJson(
            json
          );
                case 'number':
          return FormNumberSchema.fromJson(
            json
          );
                case 'boolean':
          return FormBooleanSchema.fromJson(
            json
          );
                case 'choice':
          return FormChoiceSchema.fromJson(
            json
          );
                case 'choices':
          return FormChoicesSchema.fromJson(
            json
          );
        
          default:
            return FormSchemaUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$FormFieldSchema {



  /// Serializes this FormFieldSchema to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormFieldSchema);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
@JsonSerializable()

class FormSchemaUnknown implements FormFieldSchema {
  const FormSchemaUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory FormSchemaUnknown.fromJson(Map<String, dynamic> json) => _$FormSchemaUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormSchemaUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormSchemaUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class FormTextSchema implements FormFieldSchema {
  const FormTextSchema({required this.defaultValue, @FormIntegerConverter() required this.minLength, @FormIntegerConverter() required this.maxLength, @JsonKey(unknownEnumValue: FormTextFormat.unknown) required this.format,  String? $type}): $type = $type ?? 'text';
  factory FormTextSchema.fromJson(Map<String, dynamic> json) => _$FormTextSchemaFromJson(json);

 final  String? defaultValue;
@FormIntegerConverter() final  int? minLength;
@FormIntegerConverter() final  int? maxLength;
@JsonKey(unknownEnumValue: FormTextFormat.unknown) final  FormTextFormat format;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormTextSchemaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormTextSchema&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.minLength, minLength) || other.minLength == minLength)&&(identical(other.maxLength, maxLength) || other.maxLength == maxLength)&&(identical(other.format, format) || other.format == format));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,defaultValue,minLength,maxLength,format);
}



}




/// @nodoc
@JsonSerializable()

class FormIntegerSchema implements FormFieldSchema {
  const FormIntegerSchema({@FormIntegerConverter() required this.defaultValue, @FormIntegerConverter() required this.minimum, @FormIntegerConverter() required this.maximum,  String? $type}): $type = $type ?? 'integer';
  factory FormIntegerSchema.fromJson(Map<String, dynamic> json) => _$FormIntegerSchemaFromJson(json);

@FormIntegerConverter() final  int? defaultValue;
@FormIntegerConverter() final  int? minimum;
@FormIntegerConverter() final  int? maximum;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormIntegerSchemaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormIntegerSchema&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.minimum, minimum) || other.minimum == minimum)&&(identical(other.maximum, maximum) || other.maximum == maximum));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,defaultValue,minimum,maximum);
}



}




/// @nodoc
@JsonSerializable()

class FormNumberSchema implements FormFieldSchema {
  const FormNumberSchema({@FiniteFormNumberConverter() required this.defaultValue, @FiniteFormNumberConverter() required this.minimum, @FiniteFormNumberConverter() required this.maximum,  String? $type}): $type = $type ?? 'number';
  factory FormNumberSchema.fromJson(Map<String, dynamic> json) => _$FormNumberSchemaFromJson(json);

@FiniteFormNumberConverter() final  double? defaultValue;
@FiniteFormNumberConverter() final  double? minimum;
@FiniteFormNumberConverter() final  double? maximum;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormNumberSchemaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormNumberSchema&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.minimum, minimum) || other.minimum == minimum)&&(identical(other.maximum, maximum) || other.maximum == maximum));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,defaultValue,minimum,maximum);
}



}




/// @nodoc
@JsonSerializable()

class FormBooleanSchema implements FormFieldSchema {
  const FormBooleanSchema({required this.defaultValue,  String? $type}): $type = $type ?? 'boolean';
  factory FormBooleanSchema.fromJson(Map<String, dynamic> json) => _$FormBooleanSchemaFromJson(json);

 final  bool? defaultValue;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormBooleanSchemaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormBooleanSchema&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,defaultValue);
}



}




/// @nodoc
@JsonSerializable()

class FormChoiceSchema implements FormFieldSchema {
  const FormChoiceSchema({required  List<FormChoice> options, required this.defaultOptionId,  String? $type}): _options = options,$type = $type ?? 'choice';
  factory FormChoiceSchema.fromJson(Map<String, dynamic> json) => _$FormChoiceSchemaFromJson(json);

 final  List<FormChoice> _options;
 List<FormChoice> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

 final  String? defaultOptionId;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormChoiceSchemaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormChoiceSchema&&const DeepCollectionEquality().equals(other.options, _options)&&(identical(other.defaultOptionId, defaultOptionId) || other.defaultOptionId == defaultOptionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_options),defaultOptionId);
}



}




/// @nodoc
@JsonSerializable()

class FormChoicesSchema implements FormFieldSchema {
  const FormChoicesSchema({required  List<FormChoice> options, required  List<String>? defaultOptionIds, @FormIntegerConverter() required this.minItems, @FormIntegerConverter() required this.maxItems,  String? $type}): _options = options,_defaultOptionIds = defaultOptionIds,$type = $type ?? 'choices';
  factory FormChoicesSchema.fromJson(Map<String, dynamic> json) => _$FormChoicesSchemaFromJson(json);

 final  List<FormChoice> _options;
 List<FormChoice> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

 final  List<String>? _defaultOptionIds;
 List<String>? get defaultOptionIds {
  final value = _defaultOptionIds;
  if (value == null) return null;
  if (_defaultOptionIds is EqualUnmodifiableListView) return _defaultOptionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@FormIntegerConverter() final  int? minItems;
@FormIntegerConverter() final  int? maxItems;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormChoicesSchemaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormChoicesSchema&&const DeepCollectionEquality().equals(other.options, _options)&&const DeepCollectionEquality().equals(other.defaultOptionIds, _defaultOptionIds)&&(identical(other.minItems, minItems) || other.minItems == minItems)&&(identical(other.maxItems, maxItems) || other.maxItems == maxItems));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_options),const DeepCollectionEquality().hash(_defaultOptionIds),minItems,maxItems);
}



}




// dart format on
