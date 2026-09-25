// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'v2_request_bodies.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$V2CreateSessionBody {

 LocationPublicRef get location; String? get title; String? get agent; ModelRef? get model;

  /// Serializes this V2CreateSessionBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2CreateSessionBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2CreateSessionBody&&(identical(other.location, _this.location) || other.location == _this.location)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.agent, _this.agent) || other.agent == _this.agent)&&(identical(other.model, _this.model) || other.model == _this.model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2CreateSessionBody;
  return Object.hash(runtimeType,_this.location,_this.title,_this.agent,_this.model);
}

@override
String toString() {
  final _this = this as V2CreateSessionBody;
  return 'V2CreateSessionBody(location: ${_this.location}, title: ${_this.title}, agent: ${_this.agent}, model: ${_this.model})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2CreateSessionBody implements V2CreateSessionBody {
  const _V2CreateSessionBody({required this.location, required this.title, required this.agent, required this.model});
  

@override final  LocationPublicRef location;
@override final  String? title;
@override final  String? agent;
@override final  ModelRef? model;


@override
Map<String, dynamic> toJson() {
  return _$V2CreateSessionBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2CreateSessionBody&&(identical(other.location, location) || other.location == location)&&(identical(other.title, title) || other.title == title)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,location,title,agent,model);
}

@override
String toString() {
    return 'V2CreateSessionBody(location: $location, title: $title, agent: $agent, model: $model)';
}


}




/// @nodoc
mixin _$V2RenameSessionBody {

 String get title;

  /// Serializes this V2RenameSessionBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2RenameSessionBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2RenameSessionBody&&(identical(other.title, _this.title) || other.title == _this.title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2RenameSessionBody;
  return Object.hash(runtimeType,_this.title);
}

@override
String toString() {
  final _this = this as V2RenameSessionBody;
  return 'V2RenameSessionBody(title: ${_this.title})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2RenameSessionBody implements V2RenameSessionBody {
  const _V2RenameSessionBody({required this.title});
  

@override final  String title;


@override
Map<String, dynamic> toJson() {
  return _$V2RenameSessionBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2RenameSessionBody&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,title);
}

@override
String toString() {
    return 'V2RenameSessionBody(title: $title)';
}


}




/// @nodoc
mixin _$V2SwitchAgentBody {

 String get agent;

  /// Serializes this V2SwitchAgentBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2SwitchAgentBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2SwitchAgentBody&&(identical(other.agent, _this.agent) || other.agent == _this.agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2SwitchAgentBody;
  return Object.hash(runtimeType,_this.agent);
}

@override
String toString() {
  final _this = this as V2SwitchAgentBody;
  return 'V2SwitchAgentBody(agent: ${_this.agent})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2SwitchAgentBody implements V2SwitchAgentBody {
  const _V2SwitchAgentBody({required this.agent});
  

@override final  String agent;


@override
Map<String, dynamic> toJson() {
  return _$V2SwitchAgentBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2SwitchAgentBody&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,agent);
}

@override
String toString() {
    return 'V2SwitchAgentBody(agent: $agent)';
}


}




/// @nodoc
mixin _$V2SwitchModelBody {

 ModelRef get model;

  /// Serializes this V2SwitchModelBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2SwitchModelBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2SwitchModelBody&&(identical(other.model, _this.model) || other.model == _this.model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2SwitchModelBody;
  return Object.hash(runtimeType,_this.model);
}

@override
String toString() {
  final _this = this as V2SwitchModelBody;
  return 'V2SwitchModelBody(model: ${_this.model})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2SwitchModelBody implements V2SwitchModelBody {
  const _V2SwitchModelBody({required this.model});
  

@override final  ModelRef model;


@override
Map<String, dynamic> toJson() {
  return _$V2SwitchModelBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2SwitchModelBody&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,model);
}

@override
String toString() {
    return 'V2SwitchModelBody(model: $model)';
}


}




/// @nodoc
mixin _$V2PromptBody {

 String? get id; String get text; List<PromptInputFileAttachment>? get files; List<PromptAgentAttachment>? get agents; List<PromptInputSkillAttachment>? get skills; SessionInboxDelivery? get delivery; bool? get resume;

  /// Serializes this V2PromptBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2PromptBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2PromptBody&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text)&&const DeepCollectionEquality().equals(other.files, _this.files)&&const DeepCollectionEquality().equals(other.agents, _this.agents)&&const DeepCollectionEquality().equals(other.skills, _this.skills)&&(identical(other.delivery, _this.delivery) || other.delivery == _this.delivery)&&(identical(other.resume, _this.resume) || other.resume == _this.resume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2PromptBody;
  return Object.hash(runtimeType,_this.id,_this.text,const DeepCollectionEquality().hash(_this.files),const DeepCollectionEquality().hash(_this.agents),const DeepCollectionEquality().hash(_this.skills),_this.delivery,_this.resume);
}

@override
String toString() {
  final _this = this as V2PromptBody;
  return 'V2PromptBody(id: ${_this.id}, text: ${_this.text}, files: ${_this.files}, agents: ${_this.agents}, skills: ${_this.skills}, delivery: ${_this.delivery}, resume: ${_this.resume})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2PromptBody implements V2PromptBody {
  const _V2PromptBody({required this.id, required this.text, required  List<PromptInputFileAttachment>? files, required  List<PromptAgentAttachment>? agents, required  List<PromptInputSkillAttachment>? skills, required this.delivery, required this.resume}): _files = files,_agents = agents,_skills = skills;
  

@override final  String? id;
@override final  String text;
 final  List<PromptInputFileAttachment>? _files;
@override List<PromptInputFileAttachment>? get files {
  final value = _files;
  if (value == null) return null;
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<PromptAgentAttachment>? _agents;
@override List<PromptAgentAttachment>? get agents {
  final value = _agents;
  if (value == null) return null;
  if (_agents is EqualUnmodifiableListView) return _agents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<PromptInputSkillAttachment>? _skills;
@override List<PromptInputSkillAttachment>? get skills {
  final value = _skills;
  if (value == null) return null;
  if (_skills is EqualUnmodifiableListView) return _skills;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  SessionInboxDelivery? delivery;
@override final  bool? resume;


@override
Map<String, dynamic> toJson() {
  return _$V2PromptBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2PromptBody&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.files, _files)&&const DeepCollectionEquality().equals(other.agents, _agents)&&const DeepCollectionEquality().equals(other.skills, _skills)&&(identical(other.delivery, delivery) || other.delivery == delivery)&&(identical(other.resume, resume) || other.resume == resume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text,const DeepCollectionEquality().hash(_files),const DeepCollectionEquality().hash(_agents),const DeepCollectionEquality().hash(_skills),delivery,resume);
}

@override
String toString() {
    return 'V2PromptBody(id: $id, text: $text, files: $files, agents: $agents, skills: $skills, delivery: $delivery, resume: $resume)';
}


}




/// @nodoc
mixin _$V2CommandBody {

 String get name; String get text; List<PromptInputFileAttachment>? get files; List<PromptAgentAttachment>? get agents; List<PromptInputSkillAttachment>? get skills; SessionInboxDelivery? get delivery;

  /// Serializes this V2CommandBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2CommandBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2CommandBody&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.text, _this.text) || other.text == _this.text)&&const DeepCollectionEquality().equals(other.files, _this.files)&&const DeepCollectionEquality().equals(other.agents, _this.agents)&&const DeepCollectionEquality().equals(other.skills, _this.skills)&&(identical(other.delivery, _this.delivery) || other.delivery == _this.delivery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2CommandBody;
  return Object.hash(runtimeType,_this.name,_this.text,const DeepCollectionEquality().hash(_this.files),const DeepCollectionEquality().hash(_this.agents),const DeepCollectionEquality().hash(_this.skills),_this.delivery);
}

@override
String toString() {
  final _this = this as V2CommandBody;
  return 'V2CommandBody(name: ${_this.name}, text: ${_this.text}, files: ${_this.files}, agents: ${_this.agents}, skills: ${_this.skills}, delivery: ${_this.delivery})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2CommandBody implements V2CommandBody {
  const _V2CommandBody({required this.name, required this.text, required  List<PromptInputFileAttachment>? files, required  List<PromptAgentAttachment>? agents, required  List<PromptInputSkillAttachment>? skills, required this.delivery}): _files = files,_agents = agents,_skills = skills;
  

@override final  String name;
@override final  String text;
 final  List<PromptInputFileAttachment>? _files;
@override List<PromptInputFileAttachment>? get files {
  final value = _files;
  if (value == null) return null;
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<PromptAgentAttachment>? _agents;
@override List<PromptAgentAttachment>? get agents {
  final value = _agents;
  if (value == null) return null;
  if (_agents is EqualUnmodifiableListView) return _agents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<PromptInputSkillAttachment>? _skills;
@override List<PromptInputSkillAttachment>? get skills {
  final value = _skills;
  if (value == null) return null;
  if (_skills is EqualUnmodifiableListView) return _skills;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  SessionInboxDelivery? delivery;


@override
Map<String, dynamic> toJson() {
  return _$V2CommandBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2CommandBody&&(identical(other.name, name) || other.name == name)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.files, _files)&&const DeepCollectionEquality().equals(other.agents, _agents)&&const DeepCollectionEquality().equals(other.skills, _skills)&&(identical(other.delivery, delivery) || other.delivery == delivery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,text,const DeepCollectionEquality().hash(_files),const DeepCollectionEquality().hash(_agents),const DeepCollectionEquality().hash(_skills),delivery);
}

@override
String toString() {
    return 'V2CommandBody(name: $name, text: $text, files: $files, agents: $agents, skills: $skills, delivery: $delivery)';
}


}




/// @nodoc
mixin _$V2SyntheticBody {

 String? get id; String get text; String? get description; SessionInboxDelivery? get delivery; bool? get resume;

  /// Serializes this V2SyntheticBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2SyntheticBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2SyntheticBody&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.delivery, _this.delivery) || other.delivery == _this.delivery)&&(identical(other.resume, _this.resume) || other.resume == _this.resume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2SyntheticBody;
  return Object.hash(runtimeType,_this.id,_this.text,_this.description,_this.delivery,_this.resume);
}

@override
String toString() {
  final _this = this as V2SyntheticBody;
  return 'V2SyntheticBody(id: ${_this.id}, text: ${_this.text}, description: ${_this.description}, delivery: ${_this.delivery}, resume: ${_this.resume})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2SyntheticBody implements V2SyntheticBody {
  const _V2SyntheticBody({required this.id, required this.text, required this.description, required this.delivery, required this.resume});
  

@override final  String? id;
@override final  String text;
@override final  String? description;
@override final  SessionInboxDelivery? delivery;
@override final  bool? resume;


@override
Map<String, dynamic> toJson() {
  return _$V2SyntheticBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2SyntheticBody&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.description, description) || other.description == description)&&(identical(other.delivery, delivery) || other.delivery == delivery)&&(identical(other.resume, resume) || other.resume == resume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text,description,delivery,resume);
}

@override
String toString() {
    return 'V2SyntheticBody(id: $id, text: $text, description: $description, delivery: $delivery, resume: $resume)';
}


}




/// @nodoc
mixin _$V2CompactBody {

 String? get id; SessionInboxDelivery? get delivery;

  /// Serializes this V2CompactBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2CompactBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2CompactBody&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.delivery, _this.delivery) || other.delivery == _this.delivery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2CompactBody;
  return Object.hash(runtimeType,_this.id,_this.delivery);
}

@override
String toString() {
  final _this = this as V2CompactBody;
  return 'V2CompactBody(id: ${_this.id}, delivery: ${_this.delivery})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2CompactBody implements V2CompactBody {
  const _V2CompactBody({required this.id, required this.delivery});
  

@override final  String? id;
@override final  SessionInboxDelivery? delivery;


@override
Map<String, dynamic> toJson() {
  return _$V2CompactBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2CompactBody&&(identical(other.id, id) || other.id == id)&&(identical(other.delivery, delivery) || other.delivery == delivery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,delivery);
}

@override
String toString() {
    return 'V2CompactBody(id: $id, delivery: $delivery)';
}


}




/// @nodoc
mixin _$V2PermissionReplyBody {

 PermissionReply get decision; String? get message;

  /// Serializes this V2PermissionReplyBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2PermissionReplyBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2PermissionReplyBody&&(identical(other.decision, _this.decision) || other.decision == _this.decision)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2PermissionReplyBody;
  return Object.hash(runtimeType,_this.decision,_this.message);
}

@override
String toString() {
  final _this = this as V2PermissionReplyBody;
  return 'V2PermissionReplyBody(decision: ${_this.decision}, message: ${_this.message})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2PermissionReplyBody implements V2PermissionReplyBody {
  const _V2PermissionReplyBody({required this.decision, required this.message});
  

@override final  PermissionReply decision;
@override final  String? message;


@override
Map<String, dynamic> toJson() {
  return _$V2PermissionReplyBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2PermissionReplyBody&&(identical(other.decision, decision) || other.decision == decision)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,decision,message);
}

@override
String toString() {
    return 'V2PermissionReplyBody(decision: $decision, message: $message)';
}


}




/// @nodoc
mixin _$V2UpdateProjectBody {

 String? get canonical; String? get name; ProjectIcon? get icon; ProjectCommands? get commands;

  /// Serializes this V2UpdateProjectBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as V2UpdateProjectBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2UpdateProjectBody&&(identical(other.canonical, _this.canonical) || other.canonical == _this.canonical)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.icon, _this.icon) || other.icon == _this.icon)&&(identical(other.commands, _this.commands) || other.commands == _this.commands));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2UpdateProjectBody;
  return Object.hash(runtimeType,_this.canonical,_this.name,_this.icon,_this.commands);
}

@override
String toString() {
  final _this = this as V2UpdateProjectBody;
  return 'V2UpdateProjectBody(canonical: ${_this.canonical}, name: ${_this.name}, icon: ${_this.icon}, commands: ${_this.commands})';
}


}





/// @nodoc
@JsonSerializable(createFactory: false)

class _V2UpdateProjectBody implements V2UpdateProjectBody {
  const _V2UpdateProjectBody({required this.canonical, required this.name, required this.icon, required this.commands});
  

@override final  String? canonical;
@override final  String? name;
@override final  ProjectIcon? icon;
@override final  ProjectCommands? commands;


@override
Map<String, dynamic> toJson() {
  return _$V2UpdateProjectBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2UpdateProjectBody&&(identical(other.canonical, canonical) || other.canonical == canonical)&&(identical(other.name, name) || other.name == name)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.commands, commands) || other.commands == commands));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,canonical,name,icon,commands);
}

@override
String toString() {
    return 'V2UpdateProjectBody(canonical: $canonical, name: $name, icon: $icon, commands: $commands)';
}


}




// dart format on
