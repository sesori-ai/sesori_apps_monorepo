// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_field.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FormChoice _$FormChoiceFromJson(Map json) =>
    _FormChoice(id: json['id'] as String, label: json['label'] as String);

Map<String, dynamic> _$FormChoiceToJson(_FormChoice instance) =>
    <String, dynamic>{'id': instance.id, 'label': instance.label};

_PendingFormField _$PendingFormFieldFromJson(Map json) => _PendingFormField(
  id: json['id'] as String,
  label: json['label'] as String,
  description: json['description'] as String?,
  isRequired: json['isRequired'] as bool,
  schema: FormFieldSchema.fromJson(
    Map<String, dynamic>.from(json['schema'] as Map),
  ),
);

Map<String, dynamic> _$PendingFormFieldToJson(_PendingFormField instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'description': ?instance.description,
      'isRequired': instance.isRequired,
      'schema': instance.schema.toJson(),
    };

FormSchemaUnknown _$FormSchemaUnknownFromJson(Map json) =>
    FormSchemaUnknown($type: json['type'] as String?);

Map<String, dynamic> _$FormSchemaUnknownToJson(FormSchemaUnknown instance) =>
    <String, dynamic>{'type': instance.$type};

FormTextSchema _$FormTextSchemaFromJson(Map json) => FormTextSchema(
  defaultValue: json['defaultValue'] as String?,
  minLength: _$JsonConverterFromJson<num, int>(
    json['minLength'],
    const FormIntegerConverter().fromJson,
  ),
  maxLength: _$JsonConverterFromJson<num, int>(
    json['maxLength'],
    const FormIntegerConverter().fromJson,
  ),
  format: $enumDecode(
    _$FormTextFormatEnumMap,
    json['format'],
    unknownValue: FormTextFormat.unknown,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormTextSchemaToJson(FormTextSchema instance) =>
    <String, dynamic>{
      'defaultValue': ?instance.defaultValue,
      'minLength': ?_$JsonConverterToJson<num, int>(
        instance.minLength,
        const FormIntegerConverter().toJson,
      ),
      'maxLength': ?_$JsonConverterToJson<num, int>(
        instance.maxLength,
        const FormIntegerConverter().toJson,
      ),
      'format': _$FormTextFormatEnumMap[instance.format]!,
      'type': instance.$type,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

const _$FormTextFormatEnumMap = {
  FormTextFormat.unknown: 'unknown',
  FormTextFormat.plain: 'plain',
  FormTextFormat.email: 'email',
  FormTextFormat.uri: 'uri',
  FormTextFormat.date: 'date',
  FormTextFormat.dateTime: 'dateTime',
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

FormIntegerSchema _$FormIntegerSchemaFromJson(Map json) => FormIntegerSchema(
  defaultValue: _$JsonConverterFromJson<num, int>(
    json['defaultValue'],
    const FormIntegerConverter().fromJson,
  ),
  minimum: _$JsonConverterFromJson<num, int>(
    json['minimum'],
    const FormIntegerConverter().fromJson,
  ),
  maximum: _$JsonConverterFromJson<num, int>(
    json['maximum'],
    const FormIntegerConverter().fromJson,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormIntegerSchemaToJson(FormIntegerSchema instance) =>
    <String, dynamic>{
      'defaultValue': ?_$JsonConverterToJson<num, int>(
        instance.defaultValue,
        const FormIntegerConverter().toJson,
      ),
      'minimum': ?_$JsonConverterToJson<num, int>(
        instance.minimum,
        const FormIntegerConverter().toJson,
      ),
      'maximum': ?_$JsonConverterToJson<num, int>(
        instance.maximum,
        const FormIntegerConverter().toJson,
      ),
      'type': instance.$type,
    };

FormNumberSchema _$FormNumberSchemaFromJson(Map json) => FormNumberSchema(
  defaultValue: _$JsonConverterFromJson<num, double>(
    json['defaultValue'],
    const FiniteFormNumberConverter().fromJson,
  ),
  minimum: _$JsonConverterFromJson<num, double>(
    json['minimum'],
    const FiniteFormNumberConverter().fromJson,
  ),
  maximum: _$JsonConverterFromJson<num, double>(
    json['maximum'],
    const FiniteFormNumberConverter().fromJson,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormNumberSchemaToJson(FormNumberSchema instance) =>
    <String, dynamic>{
      'defaultValue': ?_$JsonConverterToJson<num, double>(
        instance.defaultValue,
        const FiniteFormNumberConverter().toJson,
      ),
      'minimum': ?_$JsonConverterToJson<num, double>(
        instance.minimum,
        const FiniteFormNumberConverter().toJson,
      ),
      'maximum': ?_$JsonConverterToJson<num, double>(
        instance.maximum,
        const FiniteFormNumberConverter().toJson,
      ),
      'type': instance.$type,
    };

FormBooleanSchema _$FormBooleanSchemaFromJson(Map json) => FormBooleanSchema(
  defaultValue: json['defaultValue'] as bool?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormBooleanSchemaToJson(FormBooleanSchema instance) =>
    <String, dynamic>{
      'defaultValue': ?instance.defaultValue,
      'type': instance.$type,
    };

FormChoiceSchema _$FormChoiceSchemaFromJson(Map json) => FormChoiceSchema(
  options: (json['options'] as List<dynamic>)
      .map((e) => FormChoice.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  defaultOptionId: json['defaultOptionId'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormChoiceSchemaToJson(FormChoiceSchema instance) =>
    <String, dynamic>{
      'options': instance.options.map((e) => e.toJson()).toList(),
      'defaultOptionId': ?instance.defaultOptionId,
      'type': instance.$type,
    };

FormChoicesSchema _$FormChoicesSchemaFromJson(Map json) => FormChoicesSchema(
  options: (json['options'] as List<dynamic>)
      .map((e) => FormChoice.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  defaultOptionIds: (json['defaultOptionIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  minItems: _$JsonConverterFromJson<num, int>(
    json['minItems'],
    const FormIntegerConverter().fromJson,
  ),
  maxItems: _$JsonConverterFromJson<num, int>(
    json['maxItems'],
    const FormIntegerConverter().fromJson,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormChoicesSchemaToJson(FormChoicesSchema instance) =>
    <String, dynamic>{
      'options': instance.options.map((e) => e.toJson()).toList(),
      'defaultOptionIds': ?instance.defaultOptionIds,
      'minItems': ?_$JsonConverterToJson<num, int>(
        instance.minItems,
        const FormIntegerConverter().toJson,
      ),
      'maxItems': ?_$JsonConverterToJson<num, int>(
        instance.maxItems,
        const FormIntegerConverter().toJson,
      ),
      'type': instance.$type,
    };
