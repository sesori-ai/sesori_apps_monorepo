// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pending_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PageImage {

 String get path; int get width; int get height; String? get caption;

  /// Serializes this PageImage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PageImage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageImage&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.caption, _this.caption) || other.caption == _this.caption));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PageImage;
  return Object.hash(runtimeType,_this.path,_this.width,_this.height,_this.caption);
}



}





/// @nodoc
@JsonSerializable()

class _PageImage implements PageImage {
  const _PageImage({required this.path, required this.width, required this.height, required this.caption});
  factory _PageImage.fromJson(Map<String, dynamic> json) => _$PageImageFromJson(json);

@override final  String path;
@override final  int width;
@override final  int height;
@override final  String? caption;


@override
Map<String, dynamic> toJson() {
  return _$PageImageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageImage&&(identical(other.path, path) || other.path == path)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.caption, caption) || other.caption == caption));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,width,height,caption);
}



}





/// @nodoc
mixin _$PageOption {

 String get id; String get label; String? get description; PageImage? get image; bool get recommended;

  /// Serializes this PageOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PageOption;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageOption&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.image, _this.image) || other.image == _this.image)&&(identical(other.recommended, _this.recommended) || other.recommended == _this.recommended));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PageOption;
  return Object.hash(runtimeType,_this.id,_this.label,_this.description,_this.image,_this.recommended);
}



}





/// @nodoc
@JsonSerializable()

class _PageOption implements PageOption {
  const _PageOption({required this.id, required this.label, required this.description, required this.image, required this.recommended});
  factory _PageOption.fromJson(Map<String, dynamic> json) => _$PageOptionFromJson(json);

@override final  String id;
@override final  String label;
@override final  String? description;
@override final  PageImage? image;
@override final  bool recommended;


@override
Map<String, dynamic> toJson() {
  return _$PageOptionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description)&&(identical(other.image, image) || other.image == image)&&(identical(other.recommended, recommended) || other.recommended == recommended));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,label,description,image,recommended);
}



}





/// @nodoc
mixin _$PageQuestion {

 String get id; String get title; String? get body; List<PageImage> get images; PageQuestionKind get kind; bool get isRequired;

  /// Serializes this PageQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PageQuestion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageQuestion&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.body, _this.body) || other.body == _this.body)&&const DeepCollectionEquality().equals(other.images, _this.images)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.isRequired, _this.isRequired) || other.isRequired == _this.isRequired));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PageQuestion;
  return Object.hash(runtimeType,_this.id,_this.title,_this.body,const DeepCollectionEquality().hash(_this.images),_this.kind,_this.isRequired);
}



}





/// @nodoc
@JsonSerializable()

class _PageQuestion implements PageQuestion {
  const _PageQuestion({required this.id, required this.title, required this.body, required  List<PageImage> images, required this.kind, required this.isRequired}): _images = images;
  factory _PageQuestion.fromJson(Map<String, dynamic> json) => _$PageQuestionFromJson(json);

@override final  String id;
@override final  String title;
@override final  String? body;
 final  List<PageImage> _images;
@override List<PageImage> get images {
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_images);
}

@override final  PageQuestionKind kind;
@override final  bool isRequired;


@override
Map<String, dynamic> toJson() {
  return _$PageQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.images, _images)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,body,const DeepCollectionEquality().hash(_images),kind,isRequired);
}



}




PageQuestionKind _$PageQuestionKindFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'single':
          return PageSingleChoice.fromJson(
            json
          );
                case 'multiple':
          return PageMultipleChoice.fromJson(
            json
          );
                case 'text':
          return PageTextInput.fromJson(
            json
          );
        
          default:
            return PageQuestionKindUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PageQuestionKind {



  /// Serializes this PageQuestionKind to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageQuestionKind);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
@JsonSerializable()

class PageQuestionKindUnknown implements PageQuestionKind {
  const PageQuestionKindUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory PageQuestionKindUnknown.fromJson(Map<String, dynamic> json) => _$PageQuestionKindUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageQuestionKindUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageQuestionKindUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class PageSingleChoice implements PageQuestionKind {
  const PageSingleChoice({required  List<PageOption> options,  String? $type}): _options = options,$type = $type ?? 'single';
  factory PageSingleChoice.fromJson(Map<String, dynamic> json) => _$PageSingleChoiceFromJson(json);

 final  List<PageOption> _options;
 List<PageOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageSingleChoiceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageSingleChoice&&const DeepCollectionEquality().equals(other.options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_options));
}



}




/// @nodoc
@JsonSerializable()

class PageMultipleChoice implements PageQuestionKind {
  const PageMultipleChoice({required  List<PageOption> options,  String? $type}): _options = options,$type = $type ?? 'multiple';
  factory PageMultipleChoice.fromJson(Map<String, dynamic> json) => _$PageMultipleChoiceFromJson(json);

 final  List<PageOption> _options;
 List<PageOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageMultipleChoiceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageMultipleChoice&&const DeepCollectionEquality().equals(other.options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_options));
}



}




/// @nodoc
@JsonSerializable()

class PageTextInput implements PageQuestionKind {
  const PageTextInput({ String? $type}): $type = $type ?? 'text';
  factory PageTextInput.fromJson(Map<String, dynamic> json) => _$PageTextInputFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageTextInputToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageTextInput);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
mixin _$PageSection {

 String? get heading; String? get body; List<PageImage> get images; List<PageQuestion> get questions;

  /// Serializes this PageSection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PageSection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageSection&&(identical(other.heading, _this.heading) || other.heading == _this.heading)&&(identical(other.body, _this.body) || other.body == _this.body)&&const DeepCollectionEquality().equals(other.images, _this.images)&&const DeepCollectionEquality().equals(other.questions, _this.questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PageSection;
  return Object.hash(runtimeType,_this.heading,_this.body,const DeepCollectionEquality().hash(_this.images),const DeepCollectionEquality().hash(_this.questions));
}



}





/// @nodoc
@JsonSerializable()

class _PageSection implements PageSection {
  const _PageSection({required this.heading, required this.body, required  List<PageImage> images, required  List<PageQuestion> questions}): _images = images,_questions = questions;
  factory _PageSection.fromJson(Map<String, dynamic> json) => _$PageSectionFromJson(json);

@override final  String? heading;
@override final  String? body;
 final  List<PageImage> _images;
@override List<PageImage> get images {
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_images);
}

 final  List<PageQuestion> _questions;
@override List<PageQuestion> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}



@override
Map<String, dynamic> toJson() {
  return _$PageSectionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageSection&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.images, _images)&&const DeepCollectionEquality().equals(other.questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,heading,body,const DeepCollectionEquality().hash(_images),const DeepCollectionEquality().hash(_questions));
}



}





/// @nodoc
mixin _$PendingPage {

 String get id; String get sessionId; String? get displaySessionId; String get title; String? get intro; List<PageSection> get sections;

  /// Serializes this PendingPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PendingPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingPage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.displaySessionId, _this.displaySessionId) || other.displaySessionId == _this.displaySessionId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.intro, _this.intro) || other.intro == _this.intro)&&const DeepCollectionEquality().equals(other.sections, _this.sections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PendingPage;
  return Object.hash(runtimeType,_this.id,_this.sessionId,_this.displaySessionId,_this.title,_this.intro,const DeepCollectionEquality().hash(_this.sections));
}



}





/// @nodoc
@JsonSerializable()

class _PendingPage implements PendingPage {
  const _PendingPage({required this.id, required this.sessionId, required this.displaySessionId, required this.title, required this.intro, required  List<PageSection> sections}): _sections = sections;
  factory _PendingPage.fromJson(Map<String, dynamic> json) => _$PendingPageFromJson(json);

@override final  String id;
@override final  String sessionId;
@override final  String? displaySessionId;
@override final  String title;
@override final  String? intro;
 final  List<PageSection> _sections;
@override List<PageSection> get sections {
  if (_sections is EqualUnmodifiableListView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sections);
}



@override
Map<String, dynamic> toJson() {
  return _$PendingPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingPage&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId)&&(identical(other.title, title) || other.title == title)&&(identical(other.intro, intro) || other.intro == intro)&&const DeepCollectionEquality().equals(other.sections, _sections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionId,displaySessionId,title,intro,const DeepCollectionEquality().hash(_sections));
}



}





/// @nodoc
mixin _$PageAnswer {

 String get questionId; PageAnswerValue? get value; String? get note;

  /// Serializes this PageAnswer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PageAnswer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageAnswer&&(identical(other.questionId, _this.questionId) || other.questionId == _this.questionId)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.note, _this.note) || other.note == _this.note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PageAnswer;
  return Object.hash(runtimeType,_this.questionId,_this.value,_this.note);
}



}





/// @nodoc
@JsonSerializable()

class _PageAnswer implements PageAnswer {
  const _PageAnswer({required this.questionId, required this.value, required this.note});
  factory _PageAnswer.fromJson(Map<String, dynamic> json) => _$PageAnswerFromJson(json);

@override final  String questionId;
@override final  PageAnswerValue? value;
@override final  String? note;


@override
Map<String, dynamic> toJson() {
  return _$PageAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageAnswer&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.value, value) || other.value == value)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,questionId,value,note);
}



}




PageAnswerValue _$PageAnswerValueFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'choice':
          return PageChoiceAnswer.fromJson(
            json
          );
                case 'choices':
          return PageChoicesAnswer.fromJson(
            json
          );
                case 'text':
          return PageTextAnswer.fromJson(
            json
          );
        
          default:
            return PageAnswerUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PageAnswerValue {



  /// Serializes this PageAnswerValue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageAnswerValue);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
@JsonSerializable()

class PageAnswerUnknown implements PageAnswerValue {
  const PageAnswerUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory PageAnswerUnknown.fromJson(Map<String, dynamic> json) => _$PageAnswerUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageAnswerUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageAnswerUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class PageChoiceAnswer implements PageAnswerValue {
  const PageChoiceAnswer({required this.optionId,  String? $type}): $type = $type ?? 'choice';
  factory PageChoiceAnswer.fromJson(Map<String, dynamic> json) => _$PageChoiceAnswerFromJson(json);

 final  String optionId;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageChoiceAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageChoiceAnswer&&(identical(other.optionId, optionId) || other.optionId == optionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,optionId);
}



}




/// @nodoc
@JsonSerializable()

class PageChoicesAnswer implements PageAnswerValue {
  const PageChoicesAnswer({required  List<String> optionIds,  String? $type}): _optionIds = optionIds,$type = $type ?? 'choices';
  factory PageChoicesAnswer.fromJson(Map<String, dynamic> json) => _$PageChoicesAnswerFromJson(json);

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
  return _$PageChoicesAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageChoicesAnswer&&const DeepCollectionEquality().equals(other.optionIds, _optionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_optionIds));
}



}




/// @nodoc
@JsonSerializable()

class PageTextAnswer implements PageAnswerValue {
  const PageTextAnswer({required this.text,  String? $type}): $type = $type ?? 'text';
  factory PageTextAnswer.fromJson(Map<String, dynamic> json) => _$PageTextAnswerFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageTextAnswerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageTextAnswer&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text);
}



}





/// @nodoc
mixin _$SubmitPageRequest {

 String get requestId; String get sessionId; List<PageAnswer> get answers; String? get note;

  /// Serializes this SubmitPageRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SubmitPageRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubmitPageRequest&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&const DeepCollectionEquality().equals(other.answers, _this.answers)&&(identical(other.note, _this.note) || other.note == _this.note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SubmitPageRequest;
  return Object.hash(runtimeType,_this.requestId,_this.sessionId,const DeepCollectionEquality().hash(_this.answers),_this.note);
}



}





/// @nodoc
@JsonSerializable()

class _SubmitPageRequest implements SubmitPageRequest {
  const _SubmitPageRequest({required this.requestId, required this.sessionId, required  List<PageAnswer> answers, required this.note}): _answers = answers;
  factory _SubmitPageRequest.fromJson(Map<String, dynamic> json) => _$SubmitPageRequestFromJson(json);

@override final  String requestId;
@override final  String sessionId;
 final  List<PageAnswer> _answers;
@override List<PageAnswer> get answers {
  if (_answers is EqualUnmodifiableListView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_answers);
}

@override final  String? note;


@override
Map<String, dynamic> toJson() {
  return _$SubmitPageRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubmitPageRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&const DeepCollectionEquality().equals(other.answers, _answers)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,requestId,sessionId,const DeepCollectionEquality().hash(_answers),note);
}



}




PageSubmitResult _$PageSubmitResultFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'accepted':
          return PageSubmitAccepted.fromJson(
            json
          );
                case 'alreadySettled':
          return PageSubmitAlreadySettled.fromJson(
            json
          );
                case 'invalid':
          return PageSubmitInvalid.fromJson(
            json
          );
        
          default:
            return PageSubmitUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PageSubmitResult {



  /// Serializes this PageSubmitResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageSubmitResult);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
@JsonSerializable()

class PageSubmitUnknown implements PageSubmitResult {
  const PageSubmitUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory PageSubmitUnknown.fromJson(Map<String, dynamic> json) => _$PageSubmitUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageSubmitUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageSubmitUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class PageSubmitAccepted implements PageSubmitResult {
  const PageSubmitAccepted({ String? $type}): $type = $type ?? 'accepted';
  factory PageSubmitAccepted.fromJson(Map<String, dynamic> json) => _$PageSubmitAcceptedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageSubmitAcceptedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageSubmitAccepted);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class PageSubmitAlreadySettled implements PageSubmitResult {
  const PageSubmitAlreadySettled({ String? $type}): $type = $type ?? 'alreadySettled';
  factory PageSubmitAlreadySettled.fromJson(Map<String, dynamic> json) => _$PageSubmitAlreadySettledFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageSubmitAlreadySettledToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageSubmitAlreadySettled);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class PageSubmitInvalid implements PageSubmitResult {
  const PageSubmitInvalid({required  List<String> questionIds,  String? $type}): _questionIds = questionIds,$type = $type ?? 'invalid';
  factory PageSubmitInvalid.fromJson(Map<String, dynamic> json) => _$PageSubmitInvalidFromJson(json);

 final  List<String> _questionIds;
 List<String> get questionIds {
  if (_questionIds is EqualUnmodifiableListView) return _questionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questionIds);
}


@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageSubmitInvalidToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageSubmitInvalid&&const DeepCollectionEquality().equals(other.questionIds, _questionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_questionIds));
}



}





/// @nodoc
mixin _$PageLookupRequest {

 String get sessionId; String get requestId;

  /// Serializes this PageLookupRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PageLookupRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageLookupRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PageLookupRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.requestId);
}



}





/// @nodoc
@JsonSerializable()

class _PageLookupRequest implements PageLookupRequest {
  const _PageLookupRequest({required this.sessionId, required this.requestId});
  factory _PageLookupRequest.fromJson(Map<String, dynamic> json) => _$PageLookupRequestFromJson(json);

@override final  String sessionId;
@override final  String requestId;


@override
Map<String, dynamic> toJson() {
  return _$PageLookupRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageLookupRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.requestId, requestId) || other.requestId == requestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,requestId);
}



}




PageLookupResponse _$PageLookupResponseFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'pending':
          return PageLookupPending.fromJson(
            json
          );
                case 'answered':
          return PageLookupAnswered.fromJson(
            json
          );
                case 'dismissed':
          return PageLookupDismissed.fromJson(
            json
          );
                case 'missing':
          return PageLookupMissing.fromJson(
            json
          );
        
          default:
            return PageLookupUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PageLookupResponse {



  /// Serializes this PageLookupResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageLookupResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
@JsonSerializable()

class PageLookupUnknown implements PageLookupResponse {
  const PageLookupUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory PageLookupUnknown.fromJson(Map<String, dynamic> json) => _$PageLookupUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageLookupUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageLookupUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class PageLookupPending implements PageLookupResponse {
  const PageLookupPending({required this.page,  String? $type}): $type = $type ?? 'pending';
  factory PageLookupPending.fromJson(Map<String, dynamic> json) => _$PageLookupPendingFromJson(json);

 final  PendingPage page;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageLookupPendingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageLookupPending&&(identical(other.page, page) || other.page == page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,page);
}



}




/// @nodoc
@JsonSerializable()

class PageLookupAnswered implements PageLookupResponse {
  const PageLookupAnswered({required this.page, required  List<PageAnswer> answers, required this.note,  String? $type}): _answers = answers,$type = $type ?? 'answered';
  factory PageLookupAnswered.fromJson(Map<String, dynamic> json) => _$PageLookupAnsweredFromJson(json);

 final  PendingPage page;
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
  return _$PageLookupAnsweredToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageLookupAnswered&&(identical(other.page, page) || other.page == page)&&const DeepCollectionEquality().equals(other.answers, _answers)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,page,const DeepCollectionEquality().hash(_answers),note);
}



}




/// @nodoc
@JsonSerializable()

class PageLookupDismissed implements PageLookupResponse {
  const PageLookupDismissed({required this.page,  String? $type}): $type = $type ?? 'dismissed';
  factory PageLookupDismissed.fromJson(Map<String, dynamic> json) => _$PageLookupDismissedFromJson(json);

 final  PendingPage page;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageLookupDismissedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageLookupDismissed&&(identical(other.page, page) || other.page == page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,page);
}



}




/// @nodoc
@JsonSerializable()

class PageLookupMissing implements PageLookupResponse {
  const PageLookupMissing({ String? $type}): $type = $type ?? 'missing';
  factory PageLookupMissing.fromJson(Map<String, dynamic> json) => _$PageLookupMissingFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PageLookupMissingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PageLookupMissing);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




// dart format on
