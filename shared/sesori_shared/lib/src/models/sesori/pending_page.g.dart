// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PageImage _$PageImageFromJson(Map json) => _PageImage(
  path: json['path'] as String,
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  caption: json['caption'] as String?,
);

Map<String, dynamic> _$PageImageToJson(_PageImage instance) =>
    <String, dynamic>{
      'path': instance.path,
      'width': instance.width,
      'height': instance.height,
      'caption': ?instance.caption,
    };

_PageOption _$PageOptionFromJson(Map json) => _PageOption(
  id: json['id'] as String,
  label: json['label'] as String,
  description: json['description'] as String?,
  image: json['image'] == null
      ? null
      : PageImage.fromJson(Map<String, dynamic>.from(json['image'] as Map)),
  recommended: json['recommended'] as bool,
);

Map<String, dynamic> _$PageOptionToJson(_PageOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'description': ?instance.description,
      'image': ?instance.image?.toJson(),
      'recommended': instance.recommended,
    };

_PageQuestion _$PageQuestionFromJson(Map json) => _PageQuestion(
  id: json['id'] as String,
  title: json['title'] as String,
  body: json['body'] as String?,
  images: (json['images'] as List<dynamic>)
      .map((e) => PageImage.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  kind: PageQuestionKind.fromJson(
    Map<String, dynamic>.from(json['kind'] as Map),
  ),
  isRequired: json['isRequired'] as bool,
);

Map<String, dynamic> _$PageQuestionToJson(_PageQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': ?instance.body,
      'images': instance.images.map((e) => e.toJson()).toList(),
      'kind': instance.kind.toJson(),
      'isRequired': instance.isRequired,
    };

PageQuestionKindUnknown _$PageQuestionKindUnknownFromJson(Map json) =>
    PageQuestionKindUnknown($type: json['type'] as String?);

Map<String, dynamic> _$PageQuestionKindUnknownToJson(
  PageQuestionKindUnknown instance,
) => <String, dynamic>{'type': instance.$type};

PageSingleChoice _$PageSingleChoiceFromJson(Map json) => PageSingleChoice(
  options: (json['options'] as List<dynamic>)
      .map((e) => PageOption.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PageSingleChoiceToJson(PageSingleChoice instance) =>
    <String, dynamic>{
      'options': instance.options.map((e) => e.toJson()).toList(),
      'type': instance.$type,
    };

PageMultipleChoice _$PageMultipleChoiceFromJson(Map json) => PageMultipleChoice(
  options: (json['options'] as List<dynamic>)
      .map((e) => PageOption.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PageMultipleChoiceToJson(PageMultipleChoice instance) =>
    <String, dynamic>{
      'options': instance.options.map((e) => e.toJson()).toList(),
      'type': instance.$type,
    };

PageTextInput _$PageTextInputFromJson(Map json) =>
    PageTextInput($type: json['type'] as String?);

Map<String, dynamic> _$PageTextInputToJson(PageTextInput instance) =>
    <String, dynamic>{'type': instance.$type};

_PageSection _$PageSectionFromJson(Map json) => _PageSection(
  heading: json['heading'] as String?,
  body: json['body'] as String?,
  images: (json['images'] as List<dynamic>)
      .map((e) => PageImage.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  questions: (json['questions'] as List<dynamic>)
      .map((e) => PageQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

Map<String, dynamic> _$PageSectionToJson(_PageSection instance) =>
    <String, dynamic>{
      'heading': ?instance.heading,
      'body': ?instance.body,
      'images': instance.images.map((e) => e.toJson()).toList(),
      'questions': instance.questions.map((e) => e.toJson()).toList(),
    };

_PendingPage _$PendingPageFromJson(Map json) => _PendingPage(
  id: json['id'] as String,
  sessionId: json['sessionId'] as String,
  displaySessionId: json['displaySessionId'] as String?,
  title: json['title'] as String,
  intro: json['intro'] as String?,
  sections: (json['sections'] as List<dynamic>)
      .map((e) => PageSection.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

Map<String, dynamic> _$PendingPageToJson(_PendingPage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'displaySessionId': ?instance.displaySessionId,
      'title': instance.title,
      'intro': ?instance.intro,
      'sections': instance.sections.map((e) => e.toJson()).toList(),
    };

_PageAnswer _$PageAnswerFromJson(Map json) => _PageAnswer(
  questionId: json['questionId'] as String,
  value: json['value'] == null
      ? null
      : PageAnswerValue.fromJson(
          Map<String, dynamic>.from(json['value'] as Map),
        ),
  note: json['note'] as String?,
);

Map<String, dynamic> _$PageAnswerToJson(_PageAnswer instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'value': ?instance.value?.toJson(),
      'note': ?instance.note,
    };

PageAnswerUnknown _$PageAnswerUnknownFromJson(Map json) =>
    PageAnswerUnknown($type: json['type'] as String?);

Map<String, dynamic> _$PageAnswerUnknownToJson(PageAnswerUnknown instance) =>
    <String, dynamic>{'type': instance.$type};

PageChoiceAnswer _$PageChoiceAnswerFromJson(Map json) => PageChoiceAnswer(
  optionId: json['optionId'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PageChoiceAnswerToJson(PageChoiceAnswer instance) =>
    <String, dynamic>{'optionId': instance.optionId, 'type': instance.$type};

PageChoicesAnswer _$PageChoicesAnswerFromJson(Map json) => PageChoicesAnswer(
  optionIds: (json['optionIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PageChoicesAnswerToJson(PageChoicesAnswer instance) =>
    <String, dynamic>{'optionIds': instance.optionIds, 'type': instance.$type};

PageTextAnswer _$PageTextAnswerFromJson(Map json) => PageTextAnswer(
  text: json['text'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PageTextAnswerToJson(PageTextAnswer instance) =>
    <String, dynamic>{'text': instance.text, 'type': instance.$type};

_SubmitPageRequest _$SubmitPageRequestFromJson(Map json) => _SubmitPageRequest(
  requestId: json['requestId'] as String,
  sessionId: json['sessionId'] as String,
  answers: (json['answers'] as List<dynamic>)
      .map((e) => PageAnswer.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  note: json['note'] as String?,
);

Map<String, dynamic> _$SubmitPageRequestToJson(_SubmitPageRequest instance) =>
    <String, dynamic>{
      'requestId': instance.requestId,
      'sessionId': instance.sessionId,
      'answers': instance.answers.map((e) => e.toJson()).toList(),
      'note': ?instance.note,
    };

PageSubmitUnknown _$PageSubmitUnknownFromJson(Map json) =>
    PageSubmitUnknown($type: json['type'] as String?);

Map<String, dynamic> _$PageSubmitUnknownToJson(PageSubmitUnknown instance) =>
    <String, dynamic>{'type': instance.$type};

PageSubmitAccepted _$PageSubmitAcceptedFromJson(Map json) =>
    PageSubmitAccepted($type: json['type'] as String?);

Map<String, dynamic> _$PageSubmitAcceptedToJson(PageSubmitAccepted instance) =>
    <String, dynamic>{'type': instance.$type};

PageSubmitAlreadySettled _$PageSubmitAlreadySettledFromJson(Map json) =>
    PageSubmitAlreadySettled($type: json['type'] as String?);

Map<String, dynamic> _$PageSubmitAlreadySettledToJson(
  PageSubmitAlreadySettled instance,
) => <String, dynamic>{'type': instance.$type};

PageSubmitInvalid _$PageSubmitInvalidFromJson(Map json) => PageSubmitInvalid(
  questionIds: (json['questionIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PageSubmitInvalidToJson(PageSubmitInvalid instance) =>
    <String, dynamic>{
      'questionIds': instance.questionIds,
      'type': instance.$type,
    };

_PageLookupRequest _$PageLookupRequestFromJson(Map json) => _PageLookupRequest(
  sessionId: json['sessionId'] as String,
  requestId: json['requestId'] as String,
);

Map<String, dynamic> _$PageLookupRequestToJson(_PageLookupRequest instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'requestId': instance.requestId,
    };

PageLookupUnknown _$PageLookupUnknownFromJson(Map json) =>
    PageLookupUnknown($type: json['type'] as String?);

Map<String, dynamic> _$PageLookupUnknownToJson(PageLookupUnknown instance) =>
    <String, dynamic>{'type': instance.$type};

PageLookupPending _$PageLookupPendingFromJson(Map json) => PageLookupPending(
  page: PendingPage.fromJson(Map<String, dynamic>.from(json['page'] as Map)),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PageLookupPendingToJson(PageLookupPending instance) =>
    <String, dynamic>{'page': instance.page.toJson(), 'type': instance.$type};

PageLookupAnswered _$PageLookupAnsweredFromJson(Map json) => PageLookupAnswered(
  page: PendingPage.fromJson(Map<String, dynamic>.from(json['page'] as Map)),
  answers: (json['answers'] as List<dynamic>)
      .map((e) => PageAnswer.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  note: json['note'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PageLookupAnsweredToJson(PageLookupAnswered instance) =>
    <String, dynamic>{
      'page': instance.page.toJson(),
      'answers': instance.answers.map((e) => e.toJson()).toList(),
      'note': ?instance.note,
      'type': instance.$type,
    };

PageLookupDismissed _$PageLookupDismissedFromJson(Map json) =>
    PageLookupDismissed(
      page: PendingPage.fromJson(
        Map<String, dynamic>.from(json['page'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PageLookupDismissedToJson(
  PageLookupDismissed instance,
) => <String, dynamic>{'page': instance.page.toJson(), 'type': instance.$type};

PageLookupMissing _$PageLookupMissingFromJson(Map json) =>
    PageLookupMissing($type: json['type'] as String?);

Map<String, dynamic> _$PageLookupMissingToJson(PageLookupMissing instance) =>
    <String, dynamic>{'type': instance.$type};
