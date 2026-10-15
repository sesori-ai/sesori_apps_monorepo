// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FormValueUnknown _$FormValueUnknownFromJson(Map json) =>
    FormValueUnknown($type: json['type'] as String?);

Map<String, dynamic> _$FormValueUnknownToJson(FormValueUnknown instance) =>
    <String, dynamic>{'type': instance.$type};

FormTextValue _$FormTextValueFromJson(Map json) => FormTextValue(
  value: json['value'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormTextValueToJson(FormTextValue instance) =>
    <String, dynamic>{'value': instance.value, 'type': instance.$type};

FormIntegerValue _$FormIntegerValueFromJson(Map json) => FormIntegerValue(
  value: const FormIntegerConverter().fromJson(json['value'] as num),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormIntegerValueToJson(FormIntegerValue instance) =>
    <String, dynamic>{
      'value': const FormIntegerConverter().toJson(instance.value),
      'type': instance.$type,
    };

FormNumberValue _$FormNumberValueFromJson(Map json) => FormNumberValue(
  value: const FiniteFormNumberConverter().fromJson(json['value'] as num),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormNumberValueToJson(FormNumberValue instance) =>
    <String, dynamic>{
      'value': const FiniteFormNumberConverter().toJson(instance.value),
      'type': instance.$type,
    };

FormBooleanValue _$FormBooleanValueFromJson(Map json) => FormBooleanValue(
  value: json['value'] as bool,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormBooleanValueToJson(FormBooleanValue instance) =>
    <String, dynamic>{'value': instance.value, 'type': instance.$type};

FormChoiceValue _$FormChoiceValueFromJson(Map json) => FormChoiceValue(
  optionId: json['optionId'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormChoiceValueToJson(FormChoiceValue instance) =>
    <String, dynamic>{'optionId': instance.optionId, 'type': instance.$type};

FormChoicesValue _$FormChoicesValueFromJson(Map json) => FormChoicesValue(
  optionIds: (json['optionIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FormChoicesValueToJson(FormChoicesValue instance) =>
    <String, dynamic>{'optionIds': instance.optionIds, 'type': instance.$type};
