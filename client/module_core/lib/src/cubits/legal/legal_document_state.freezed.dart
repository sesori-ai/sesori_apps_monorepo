// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'legal_document_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LegalDocumentState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LegalDocumentState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LegalDocumentState()';
}


}

/// @nodoc
class $LegalDocumentStateCopyWith<$Res>  {
$LegalDocumentStateCopyWith(LegalDocumentState _, $Res Function(LegalDocumentState) __);
}



/// @nodoc


class LegalDocumentLoading implements LegalDocumentState {
  const LegalDocumentLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LegalDocumentLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LegalDocumentState.loading()';
}


}




/// @nodoc


class LegalDocumentLoaded implements LegalDocumentState {
  const LegalDocumentLoaded({required this.markdown});
  

 final  String markdown;

/// Create a copy of LegalDocumentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LegalDocumentLoadedCopyWith<LegalDocumentLoaded> get copyWith => _$LegalDocumentLoadedCopyWithImpl<LegalDocumentLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LegalDocumentLoaded&&(identical(other.markdown, markdown) || other.markdown == markdown));
}


@override
int get hashCode => Object.hash(runtimeType,markdown);

@override
String toString() {
  return 'LegalDocumentState.loaded(markdown: $markdown)';
}


}

/// @nodoc
abstract mixin class $LegalDocumentLoadedCopyWith<$Res> implements $LegalDocumentStateCopyWith<$Res> {
  factory $LegalDocumentLoadedCopyWith(LegalDocumentLoaded value, $Res Function(LegalDocumentLoaded) _then) = _$LegalDocumentLoadedCopyWithImpl;
@useResult
$Res call({
 String markdown
});




}
/// @nodoc
class _$LegalDocumentLoadedCopyWithImpl<$Res>
    implements $LegalDocumentLoadedCopyWith<$Res> {
  _$LegalDocumentLoadedCopyWithImpl(this._self, this._then);

  final LegalDocumentLoaded _self;
  final $Res Function(LegalDocumentLoaded) _then;

/// Create a copy of LegalDocumentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? markdown = null,}) {
  return _then(LegalDocumentLoaded(
markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LegalDocumentFailed implements LegalDocumentState {
  const LegalDocumentFailed({required this.reason});
  

 final  RemoteFailureReason reason;

/// Create a copy of LegalDocumentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LegalDocumentFailedCopyWith<LegalDocumentFailed> get copyWith => _$LegalDocumentFailedCopyWithImpl<LegalDocumentFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LegalDocumentFailed&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'LegalDocumentState.failed(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $LegalDocumentFailedCopyWith<$Res> implements $LegalDocumentStateCopyWith<$Res> {
  factory $LegalDocumentFailedCopyWith(LegalDocumentFailed value, $Res Function(LegalDocumentFailed) _then) = _$LegalDocumentFailedCopyWithImpl;
@useResult
$Res call({
 RemoteFailureReason reason
});




}
/// @nodoc
class _$LegalDocumentFailedCopyWithImpl<$Res>
    implements $LegalDocumentFailedCopyWith<$Res> {
  _$LegalDocumentFailedCopyWithImpl(this._self, this._then);

  final LegalDocumentFailed _self;
  final $Res Function(LegalDocumentFailed) _then;

/// Create a copy of LegalDocumentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(LegalDocumentFailed(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}


}

// dart format on
