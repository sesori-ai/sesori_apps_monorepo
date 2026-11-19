// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
AgentPageOutcome _$AgentPageOutcomeFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'answered':
          return AgentPageAnswered.fromJson(
            json
          );
                case 'dismissed':
          return AgentPageDismissed.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'AgentPageOutcome',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$AgentPageOutcome {



  /// Serializes this AgentPageOutcome to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentPageOutcome);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AgentPageOutcome()';
}


}





/// @nodoc
@JsonSerializable()

class AgentPageAnswered extends AgentPageOutcome {
  const AgentPageAnswered({required  List<PageAnswer> answers, required this.note,  String? $type}): _answers = answers,$type = $type ?? 'answered',super._();
  factory AgentPageAnswered.fromJson(Map<String, dynamic> json) => _$AgentPageAnsweredFromJson(json);

 final  List<PageAnswer> _answers;
 List<PageAnswer> get answers {
  if (_answers is EqualUnmodifiableListView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_answers);
}

 final  String? note;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AgentPageAnsweredToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentPageAnswered&&const DeepCollectionEquality().equals(other.answers, _answers)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_answers),note);
}

@override
String toString() {
    return 'AgentPageOutcome.answered(answers: $answers, note: $note)';
}


}




/// @nodoc
@JsonSerializable()

class AgentPageDismissed extends AgentPageOutcome {
  const AgentPageDismissed({ String? $type}): $type = $type ?? 'dismissed',super._();
  factory AgentPageDismissed.fromJson(Map<String, dynamic> json) => _$AgentPageDismissedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AgentPageDismissedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentPageDismissed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AgentPageOutcome.dismissed()';
}


}




// dart format on
