// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feedback_prompt_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
FeedbackPromptState _$FeedbackPromptStateFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'counting':
          return FeedbackPromptCounting.fromJson(
            json
          );
                case 'retired':
          return FeedbackPromptRetired.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'FeedbackPromptState',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$FeedbackPromptState {



  /// Serializes this FeedbackPromptState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackPromptState);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackPromptState()';
}


}

/// @nodoc
class $FeedbackPromptStateCopyWith<$Res>  {
$FeedbackPromptStateCopyWith(FeedbackPromptState _, $Res Function(FeedbackPromptState) __);
}



/// @nodoc
@JsonSerializable()

class FeedbackPromptCounting implements FeedbackPromptState {
  const FeedbackPromptCounting({ Map<String, int> pointsBySession = const <String, int>{}, required this.lastShownAt,  String? $type}): _pointsBySession = pointsBySession,$type = $type ?? 'counting';
  factory FeedbackPromptCounting.fromJson(Map<String, dynamic> json) => _$FeedbackPromptCountingFromJson(json);

 final  Map<String, int> _pointsBySession;
@JsonKey() Map<String, int> get pointsBySession {
  if (_pointsBySession is EqualUnmodifiableMapView) return _pointsBySession;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_pointsBySession);
}

 final  DateTime? lastShownAt;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of FeedbackPromptState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedbackPromptCountingCopyWith<FeedbackPromptCounting> get copyWith => _$FeedbackPromptCountingCopyWithImpl<FeedbackPromptCounting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedbackPromptCountingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackPromptCounting&&const DeepCollectionEquality().equals(other.pointsBySession, _pointsBySession)&&(identical(other.lastShownAt, lastShownAt) || other.lastShownAt == lastShownAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_pointsBySession),lastShownAt);
}

@override
String toString() {
    return 'FeedbackPromptState.counting(pointsBySession: $pointsBySession, lastShownAt: $lastShownAt)';
}


}

/// @nodoc
abstract mixin class $FeedbackPromptCountingCopyWith<$Res> implements $FeedbackPromptStateCopyWith<$Res> {
  factory $FeedbackPromptCountingCopyWith(FeedbackPromptCounting value, $Res Function(FeedbackPromptCounting) _then) = _$FeedbackPromptCountingCopyWithImpl;
@useResult
$Res call({
 Map<String, int> pointsBySession, DateTime? lastShownAt
});




}
/// @nodoc
class _$FeedbackPromptCountingCopyWithImpl<$Res>
    implements $FeedbackPromptCountingCopyWith<$Res> {
  _$FeedbackPromptCountingCopyWithImpl(this._self, this._then);

  final FeedbackPromptCounting _self;
  final $Res Function(FeedbackPromptCounting) _then;

/// Create a copy of FeedbackPromptState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pointsBySession = null,Object? lastShownAt = freezed,}) {
  return _then(FeedbackPromptCounting(
pointsBySession: null == pointsBySession ? _self._pointsBySession : pointsBySession // ignore: cast_nullable_to_non_nullable
as Map<String, int>,lastShownAt: freezed == lastShownAt ? _self.lastShownAt : lastShownAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class FeedbackPromptRetired implements FeedbackPromptState {
  const FeedbackPromptRetired({ String? $type}): $type = $type ?? 'retired';
  factory FeedbackPromptRetired.fromJson(Map<String, dynamic> json) => _$FeedbackPromptRetiredFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FeedbackPromptRetiredToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackPromptRetired);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackPromptState.retired()';
}


}




// dart format on
