// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sesori_mcp_tool_arguments.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ListTasksArguments {

@JsonKey(name: "project_id") String? get projectId;





@override
String toString() {
  final _this = this as ListTasksArguments;
  return 'ListTasksArguments(projectId: ${_this.projectId})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _ListTasksArguments implements ListTasksArguments {
  const _ListTasksArguments({@JsonKey(name: "project_id") required this.projectId});
  factory _ListTasksArguments.fromJson(Map<String, dynamic> json) => _$ListTasksArgumentsFromJson(json);

@override@JsonKey(name: "project_id") final  String? projectId;






@override
String toString() {
    return 'ListTasksArguments(projectId: $projectId)';
}


}





/// @nodoc
mixin _$GetTaskArguments {

@JsonKey(name: "task_id") String? get taskId;





@override
String toString() {
  final _this = this as GetTaskArguments;
  return 'GetTaskArguments(taskId: ${_this.taskId})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _GetTaskArguments implements GetTaskArguments {
  const _GetTaskArguments({@JsonKey(name: "task_id") required this.taskId});
  factory _GetTaskArguments.fromJson(Map<String, dynamic> json) => _$GetTaskArgumentsFromJson(json);

@override@JsonKey(name: "task_id") final  String? taskId;






@override
String toString() {
    return 'GetTaskArguments(taskId: $taskId)';
}


}





/// @nodoc
mixin _$TaskIdArguments {

@JsonKey(name: "task_id") String get taskId;





@override
String toString() {
  final _this = this as TaskIdArguments;
  return 'TaskIdArguments(taskId: ${_this.taskId})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _TaskIdArguments implements TaskIdArguments {
  const _TaskIdArguments({@JsonKey(name: "task_id") required this.taskId});
  factory _TaskIdArguments.fromJson(Map<String, dynamic> json) => _$TaskIdArgumentsFromJson(json);

@override@JsonKey(name: "task_id") final  String taskId;






@override
String toString() {
    return 'TaskIdArguments(taskId: $taskId)';
}


}





/// @nodoc
mixin _$GetTaskRunTranscriptArguments {

@JsonKey(name: "task_id") String get taskId;@JsonKey(name: "run_id") String get runId;/// The previous page's `next_page`; null for the newest page.
 int? get page;





@override
String toString() {
  final _this = this as GetTaskRunTranscriptArguments;
  return 'GetTaskRunTranscriptArguments(taskId: ${_this.taskId}, runId: ${_this.runId}, page: ${_this.page})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _GetTaskRunTranscriptArguments implements GetTaskRunTranscriptArguments {
  const _GetTaskRunTranscriptArguments({@JsonKey(name: "task_id") required this.taskId, @JsonKey(name: "run_id") required this.runId, required this.page});
  factory _GetTaskRunTranscriptArguments.fromJson(Map<String, dynamic> json) => _$GetTaskRunTranscriptArgumentsFromJson(json);

@override@JsonKey(name: "task_id") final  String taskId;
@override@JsonKey(name: "run_id") final  String runId;
/// The previous page's `next_page`; null for the newest page.
@override final  int? page;






@override
String toString() {
    return 'GetTaskRunTranscriptArguments(taskId: $taskId, runId: $runId, page: $page)';
}


}





/// @nodoc
mixin _$CreateTaskArguments {

 String get name; String get prompt; TaskSchedule get schedule;@JsonKey(name: "time_zone") String get timeZone;/// Null for the caller's project.
@JsonKey(name: "project_id") String? get projectId;@JsonKey(name: "missed_run_policy") TaskMissedRunPolicy get missedRunPolicy;@JsonKey(name: "run_mode") TaskRunMode get runMode; String? get model; String? get effort;@JsonKey(name: "approval_mode") TaskApprovalMode get approvalMode;





@override
String toString() {
  final _this = this as CreateTaskArguments;
  return 'CreateTaskArguments(name: ${_this.name}, prompt: ${_this.prompt}, schedule: ${_this.schedule}, timeZone: ${_this.timeZone}, projectId: ${_this.projectId}, missedRunPolicy: ${_this.missedRunPolicy}, runMode: ${_this.runMode}, model: ${_this.model}, effort: ${_this.effort}, approvalMode: ${_this.approvalMode})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _CreateTaskArguments implements CreateTaskArguments {
  const _CreateTaskArguments({required this.name, required this.prompt, required this.schedule, @JsonKey(name: "time_zone") required this.timeZone, @JsonKey(name: "project_id") required this.projectId, @JsonKey(name: "missed_run_policy") this.missedRunPolicy = TaskMissedRunPolicy.runWhenBack, @JsonKey(name: "run_mode") this.runMode = const TaskRunMode.newSession(), required this.model, required this.effort, @JsonKey(name: "approval_mode") this.approvalMode = TaskApprovalMode.ask});
  factory _CreateTaskArguments.fromJson(Map<String, dynamic> json) => _$CreateTaskArgumentsFromJson(json);

@override final  String name;
@override final  String prompt;
@override final  TaskSchedule schedule;
@override@JsonKey(name: "time_zone") final  String timeZone;
/// Null for the caller's project.
@override@JsonKey(name: "project_id") final  String? projectId;
@override@JsonKey(name: "missed_run_policy") final  TaskMissedRunPolicy missedRunPolicy;
@override@JsonKey(name: "run_mode") final  TaskRunMode runMode;
@override final  String? model;
@override final  String? effort;
@override@JsonKey(name: "approval_mode") final  TaskApprovalMode approvalMode;






@override
String toString() {
    return 'CreateTaskArguments(name: $name, prompt: $prompt, schedule: $schedule, timeZone: $timeZone, projectId: $projectId, missedRunPolicy: $missedRunPolicy, runMode: $runMode, model: $model, effort: $effort, approvalMode: $approvalMode)';
}


}





/// @nodoc
mixin _$UpdateTaskArguments {

@JsonKey(name: "task_id") String get taskId; String? get name; String? get prompt;@JsonKey(name: "command_arguments") String? get commandArguments; TaskSchedule? get schedule;@JsonKey(name: "time_zone") String? get timeZone;@JsonKey(name: "missed_run_policy") TaskMissedRunPolicy? get missedRunPolicy;@JsonKey(name: "run_mode") TaskRunMode? get runMode; String? get model; String? get effort;@JsonKey(name: "approval_mode") TaskApprovalMode? get approvalMode;





@override
String toString() {
  final _this = this as UpdateTaskArguments;
  return 'UpdateTaskArguments(taskId: ${_this.taskId}, name: ${_this.name}, prompt: ${_this.prompt}, commandArguments: ${_this.commandArguments}, schedule: ${_this.schedule}, timeZone: ${_this.timeZone}, missedRunPolicy: ${_this.missedRunPolicy}, runMode: ${_this.runMode}, model: ${_this.model}, effort: ${_this.effort}, approvalMode: ${_this.approvalMode})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _UpdateTaskArguments implements UpdateTaskArguments {
  const _UpdateTaskArguments({@JsonKey(name: "task_id") required this.taskId, required this.name, required this.prompt, @JsonKey(name: "command_arguments") required this.commandArguments, required this.schedule, @JsonKey(name: "time_zone") required this.timeZone, @JsonKey(name: "missed_run_policy") required this.missedRunPolicy, @JsonKey(name: "run_mode") required this.runMode, required this.model, required this.effort, @JsonKey(name: "approval_mode") required this.approvalMode});
  factory _UpdateTaskArguments.fromJson(Map<String, dynamic> json) => _$UpdateTaskArgumentsFromJson(json);

@override@JsonKey(name: "task_id") final  String taskId;
@override final  String? name;
@override final  String? prompt;
@override@JsonKey(name: "command_arguments") final  String? commandArguments;
@override final  TaskSchedule? schedule;
@override@JsonKey(name: "time_zone") final  String? timeZone;
@override@JsonKey(name: "missed_run_policy") final  TaskMissedRunPolicy? missedRunPolicy;
@override@JsonKey(name: "run_mode") final  TaskRunMode? runMode;
@override final  String? model;
@override final  String? effort;
@override@JsonKey(name: "approval_mode") final  TaskApprovalMode? approvalMode;






@override
String toString() {
    return 'UpdateTaskArguments(taskId: $taskId, name: $name, prompt: $prompt, commandArguments: $commandArguments, schedule: $schedule, timeZone: $timeZone, missedRunPolicy: $missedRunPolicy, runMode: $runMode, model: $model, effort: $effort, approvalMode: $approvalMode)';
}


}





/// @nodoc
mixin _$SendPageArguments {

 String get title; String? get intro; List<PageSectionArgument> get sections;





@override
String toString() {
  final _this = this as SendPageArguments;
  return 'SendPageArguments(title: ${_this.title}, intro: ${_this.intro}, sections: ${_this.sections})';
}


}





/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
class _SendPageArguments implements SendPageArguments {
  const _SendPageArguments({required this.title, required this.intro, required  List<PageSectionArgument> sections}): _sections = sections;
  factory _SendPageArguments.fromJson(Map<String, dynamic> json) => _$SendPageArgumentsFromJson(json);

@override final  String title;
@override final  String? intro;
 final  List<PageSectionArgument> _sections;
@override List<PageSectionArgument> get sections {
  if (_sections is EqualUnmodifiableListView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sections);
}







@override
String toString() {
    return 'SendPageArguments(title: $title, intro: $intro, sections: $sections)';
}


}





/// @nodoc
mixin _$PageSectionArgument {

 String? get heading; String? get body; List<PageImageArgument>? get images; List<PageQuestionArgument>? get questions;





@override
String toString() {
  final _this = this as PageSectionArgument;
  return 'PageSectionArgument(heading: ${_this.heading}, body: ${_this.body}, images: ${_this.images}, questions: ${_this.questions})';
}


}





/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
class _PageSectionArgument implements PageSectionArgument {
  const _PageSectionArgument({required this.heading, required this.body, required  List<PageImageArgument>? images, required  List<PageQuestionArgument>? questions}): _images = images,_questions = questions;
  factory _PageSectionArgument.fromJson(Map<String, dynamic> json) => _$PageSectionArgumentFromJson(json);

@override final  String? heading;
@override final  String? body;
 final  List<PageImageArgument>? _images;
@override List<PageImageArgument>? get images {
  final value = _images;
  if (value == null) return null;
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<PageQuestionArgument>? _questions;
@override List<PageQuestionArgument>? get questions {
  final value = _questions;
  if (value == null) return null;
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}







@override
String toString() {
    return 'PageSectionArgument(heading: $heading, body: $body, images: $images, questions: $questions)';
}


}





/// @nodoc
mixin _$PageImageArgument {

 String get path; String? get caption;





@override
String toString() {
  final _this = this as PageImageArgument;
  return 'PageImageArgument(path: ${_this.path}, caption: ${_this.caption})';
}


}





/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
class _PageImageArgument implements PageImageArgument {
  const _PageImageArgument({required this.path, required this.caption});
  factory _PageImageArgument.fromJson(Map<String, dynamic> json) => _$PageImageArgumentFromJson(json);

@override final  String path;
@override final  String? caption;






@override
String toString() {
    return 'PageImageArgument(path: $path, caption: $caption)';
}


}





/// @nodoc
mixin _$PageQuestionArgument {

 String get id; String get title; String? get body; List<PageImageArgument>? get images; PageQuestionKindArgument get kind;/// Only for single and multiple; text questions take none.
 List<PageOptionArgument>? get options; bool get required;





@override
String toString() {
  final _this = this as PageQuestionArgument;
  return 'PageQuestionArgument(id: ${_this.id}, title: ${_this.title}, body: ${_this.body}, images: ${_this.images}, kind: ${_this.kind}, options: ${_this.options}, required: ${_this.required})';
}


}





/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
class _PageQuestionArgument implements PageQuestionArgument {
  const _PageQuestionArgument({required this.id, required this.title, required this.body, required  List<PageImageArgument>? images, required this.kind, required  List<PageOptionArgument>? options, this.required = false}): _images = images,_options = options;
  factory _PageQuestionArgument.fromJson(Map<String, dynamic> json) => _$PageQuestionArgumentFromJson(json);

@override final  String id;
@override final  String title;
@override final  String? body;
 final  List<PageImageArgument>? _images;
@override List<PageImageArgument>? get images {
  final value = _images;
  if (value == null) return null;
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  PageQuestionKindArgument kind;
/// Only for single and multiple; text questions take none.
 final  List<PageOptionArgument>? _options;
/// Only for single and multiple; text questions take none.
@override List<PageOptionArgument>? get options {
  final value = _options;
  if (value == null) return null;
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool required;






@override
String toString() {
    return 'PageQuestionArgument(id: $id, title: $title, body: $body, images: $images, kind: $kind, options: $options, required: $required)';
}


}





/// @nodoc
mixin _$PageOptionArgument {

 String get id; String get label; String? get description; PageImageArgument? get image; bool get recommended;





@override
String toString() {
  final _this = this as PageOptionArgument;
  return 'PageOptionArgument(id: ${_this.id}, label: ${_this.label}, description: ${_this.description}, image: ${_this.image}, recommended: ${_this.recommended})';
}


}





/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
class _PageOptionArgument implements PageOptionArgument {
  const _PageOptionArgument({required this.id, required this.label, required this.description, required this.image, this.recommended = false});
  factory _PageOptionArgument.fromJson(Map<String, dynamic> json) => _$PageOptionArgumentFromJson(json);

@override final  String id;
@override final  String label;
@override final  String? description;
@override final  PageImageArgument? image;
@override@JsonKey() final  bool recommended;






@override
String toString() {
    return 'PageOptionArgument(id: $id, label: $label, description: $description, image: $image, recommended: $recommended)';
}


}




// dart format on
