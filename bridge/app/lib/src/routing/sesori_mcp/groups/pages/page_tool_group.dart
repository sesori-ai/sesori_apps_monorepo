import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageBytes;
import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../../../../repositories/models/sesori_tool_group_ids.dart";
import "../../../../services/agent_page_service.dart";
import "../../models/sesori_mcp_tool_arguments.dart";
import "../in_app_tool_texts.dart";
import "page_tool.dart";

/// `send_page`: asking the user on a page in the Sesori app.
class PageToolGroup({required final AgentPageService _pages}) implements SesoriToolGroup {
  static const int _mebibyte = 1024 * 1024;

  /// Where each nested page argument sits, keyed by the class checked
  /// decoding reports: Freezed's generated `_<Model>` for each model, so a
  /// renamed model fails to compile here instead of losing its place.
  static final SesoriToolArgumentParser _arguments = SesoriToolArgumentParser(
    nestedPlaces: {
      "_$PageSectionArgument": "sections[].",
      "_$PageQuestionArgument": "sections[].questions[].",
      "_$PageOptionArgument": "sections[].questions[].options[].",
      "_$PageImageArgument": "images[].",
    },
    kindFields: const {},
  );

  @override
  SesoriToolGroupId get id => SesoriToolGroupIds.pages;

  @override
  String get title => "Pages";

  @override
  String get summary => "Agents can ask you questions on a page in the app.";

  @override
  String get instructions =>
      "send_page asks the user on a page in the Sesori app. It returns at once and Sesori messages this session "
      "with the user's answer, so don't poll for it.";

  @override
  List<SesoriToolDefinition> get tools => [for (final tool in PageTool.values) tool.definition];

  @override
  Future<SesoriToolResult> call({
    required String tool,
    required SesoriToolCaller caller,
    required Map<String, Object?> arguments,
  }) async {
    switch (PageTool.values.firstWhere((candidate) => candidate.wireName == tool)) {
      case PageTool.sendPage:
        final args = _arguments.parse(json: arguments, fromJson: SendPageArguments.fromJson);
        return _pageSent(
          result: await _pages.send(
            caller: caller,
            draft: _pageDraft(args: args),
          ),
        );
    }
  }

  SesoriToolResult _pageSent({required AgentPageSendResult result}) {
    final text = switch (result) {
      AgentPageSent(:final page) => "Sent “${page.title}” to the user. $answerFollowsText",
      AgentPageCallerGone() => callerGoneText,
      AgentPageOverLimit(limit: AgentPageLimit.titleLength) =>
        "title is longer than ${AgentPageService.maxTitleLength} characters.",
      AgentPageOverLimit(limit: AgentPageLimit.images) =>
        "The page has more than ${AgentPageService.maxImages} images.",
      AgentPageOverLimit(limit: AgentPageLimit.questions) =>
        "The page has more than ${AgentPageService.maxQuestions} questions.",
      AgentPageOverLimit(limit: AgentPageLimit.imageBytes) =>
        "The page's images are over ${AgentPageService.maxPageImageBytes ~/ _mebibyte} MiB together.",
      AgentPageTooManyOptions(:final questionId) =>
        "Question $questionId has more than ${AgentPageService.maxOptions} options.",
      AgentPageDuplicateQuestionId(:final questionId) => "Two questions have the id $questionId.",
      AgentPageDuplicateOptionId(:final questionId, :final optionId) =>
        "Question $questionId has two options with the id $optionId.",
      AgentPageImageRejected(:final path, :final problem) => switch (problem) {
        AgentPageImageProblem.notAbsolute => "Image path $path is not absolute.",
        AgentPageImageProblem.missing => "No file at image path $path.",
        AgentPageImageProblem.denied => "The bridge may not read image path $path.",
        AgentPageImageProblem.tooLarge => "The image at $path is over ${maxTranscriptImageBytes ~/ _mebibyte} MiB.",
        AgentPageImageProblem.notImage => "The file at $path is not a png, jpg, gif or webp image.",
      },
    };
    return result is AgentPageSent ? SesoriToolSuccess(text: text) : SesoriToolFailure(text: text);
  }

  /// [args] as the page service takes them. Strict-schema providers fill
  /// fields they leave out with "", so an empty optional text reads as
  /// absent, an empty required one as missing, and an image with neither a
  /// path nor a caption as no image.
  AgentPageDraft _pageDraft({required SendPageArguments args}) {
    return AgentPageDraft(
      title: requiredToolText(value: args.title, field: "title"),
      intro: optionalToolText(value: args.intro),
      sections: [
        for (final (sectionIndex, section) in args.sections.indexed)
          AgentPageSectionDraft(
            heading: optionalToolText(value: section.heading),
            body: optionalToolText(value: section.body),
            images: _pageImages(images: section.images ?? const [], field: "sections[$sectionIndex].images"),
            questions: [
              for (final (questionIndex, question) in (section.questions ?? const <PageQuestionArgument>[]).indexed)
                _pageQuestion(question: question, field: "sections[$sectionIndex].questions[$questionIndex]"),
            ],
          ),
      ],
    );
  }

  AgentPageQuestionDraft _pageQuestion({required PageQuestionArgument question, required String field}) {
    final options = [
      for (final (index, option) in (question.options ?? const <PageOptionArgument>[]).indexed)
        AgentPageOptionDraft(
          id: requiredToolText(value: option.id, field: "$field.options[$index].id"),
          label: requiredToolText(value: option.label, field: "$field.options[$index].label"),
          description: optionalToolText(value: option.description),
          image: switch (option.image) {
            final image? => _pageImage(image: image, field: "$field.options[$index].image"),
            null => null,
          },
          recommended: option.recommended,
        ),
    ];
    return AgentPageQuestionDraft(
      id: requiredToolText(value: question.id, field: "$field.id"),
      title: requiredToolText(value: question.title, field: "$field.title"),
      body: optionalToolText(value: question.body),
      images: _pageImages(images: question.images ?? const [], field: "$field.images"),
      kind: switch (question.kind) {
        PageQuestionKindArgument.single || PageQuestionKindArgument.multiple when options.isEmpty =>
          throw InvalidToolArguments(reason: "$field.options is required when its kind is ${question.kind.name}."),
        PageQuestionKindArgument.single => AgentPageSingleChoiceDraft(options: options),
        PageQuestionKindArgument.multiple => AgentPageMultipleChoiceDraft(options: options),
        PageQuestionKindArgument.text when options.isEmpty => const AgentPageTextDraft(),
        PageQuestionKindArgument.text => throw InvalidToolArguments(
          reason: "$field.options are only for single and multiple questions.",
        ),
      },
      isRequired: question.required,
    );
  }

  List<AgentPageImageDraft> _pageImages({required List<PageImageArgument> images, required String field}) => [
    for (final (index, image) in images.indexed) ?_pageImage(image: image, field: "$field[$index]"),
  ];

  /// [image] as the page service takes it, or null for an image with an empty
  /// path and no caption, which is how strict-schema providers fill in one
  /// they leave out.
  AgentPageImageDraft? _pageImage({required PageImageArgument image, required String field}) {
    final caption = optionalToolText(value: image.caption);
    if (caption == null && image.path.trim().isEmpty) return null;
    return AgentPageImageDraft(
      path: requiredToolText(value: image.path, field: "$field.path"),
      caption: caption,
    );
  }
}
