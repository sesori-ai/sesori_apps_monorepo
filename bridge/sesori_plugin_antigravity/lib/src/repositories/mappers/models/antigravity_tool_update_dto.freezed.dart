// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'antigravity_tool_update_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AntigravityToolUpdateDto {

@JsonKey(unknownEnumValue: AntigravityUpdateKind.unknown) AntigravityUpdateKind get sessionUpdate; String? get title; String? get kind; Object? get rawInput; Object? get rawOutput;@JsonKey(name: "_meta") Object? get metadata;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityToolUpdateDto implements AntigravityToolUpdateDto {
  const _AntigravityToolUpdateDto({@JsonKey(unknownEnumValue: AntigravityUpdateKind.unknown) required this.sessionUpdate, required this.title, required this.kind, required this.rawInput, required this.rawOutput, @JsonKey(name: "_meta") required this.metadata});
  factory _AntigravityToolUpdateDto.fromJson(Map<String, dynamic> json) => _$AntigravityToolUpdateDtoFromJson(json);

@override@JsonKey(unknownEnumValue: AntigravityUpdateKind.unknown) final  AntigravityUpdateKind sessionUpdate;
@override final  String? title;
@override final  String? kind;
@override final  Object? rawInput;
@override final  Object? rawOutput;
@override@JsonKey(name: "_meta") final  Object? metadata;








}





/// @nodoc
mixin _$AntigravityNativeToolFieldsDto {

 String? get command;@JsonKey(name: "CommandLine") String? get upperCommandLine;@JsonKey(name: "command_line") String? get snakeCommandLine; String? get commandLine; String? get cwd;@JsonKey(name: "Cwd") String? get upperCwd;@JsonKey(name: "WorkingDirectory") String? get workingDirectory;@JsonKey(name: "working_dir") String? get snakeWorkingDir; String? get workingDir; String? get stdout; String? get stderr; String? get combinedOutput;@JsonKey(name: "combined_output") String? get snakeCombinedOutput;@JsonKey(name: "formatted_output") String? get formattedOutput; int? get exitCode;@JsonKey(name: "exit_code") int? get snakeExitCode; String? get imagePath;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityNativeToolFieldsDto implements AntigravityNativeToolFieldsDto {
  const _AntigravityNativeToolFieldsDto({required this.command, @JsonKey(name: "CommandLine") required this.upperCommandLine, @JsonKey(name: "command_line") required this.snakeCommandLine, required this.commandLine, required this.cwd, @JsonKey(name: "Cwd") required this.upperCwd, @JsonKey(name: "WorkingDirectory") required this.workingDirectory, @JsonKey(name: "working_dir") required this.snakeWorkingDir, required this.workingDir, required this.stdout, required this.stderr, required this.combinedOutput, @JsonKey(name: "combined_output") required this.snakeCombinedOutput, @JsonKey(name: "formatted_output") required this.formattedOutput, required this.exitCode, @JsonKey(name: "exit_code") required this.snakeExitCode, required this.imagePath});
  factory _AntigravityNativeToolFieldsDto.fromJson(Map<String, dynamic> json) => _$AntigravityNativeToolFieldsDtoFromJson(json);

@override final  String? command;
@override@JsonKey(name: "CommandLine") final  String? upperCommandLine;
@override@JsonKey(name: "command_line") final  String? snakeCommandLine;
@override final  String? commandLine;
@override final  String? cwd;
@override@JsonKey(name: "Cwd") final  String? upperCwd;
@override@JsonKey(name: "WorkingDirectory") final  String? workingDirectory;
@override@JsonKey(name: "working_dir") final  String? snakeWorkingDir;
@override final  String? workingDir;
@override final  String? stdout;
@override final  String? stderr;
@override final  String? combinedOutput;
@override@JsonKey(name: "combined_output") final  String? snakeCombinedOutput;
@override@JsonKey(name: "formatted_output") final  String? formattedOutput;
@override final  int? exitCode;
@override@JsonKey(name: "exit_code") final  int? snakeExitCode;
@override final  String? imagePath;








}




/// @nodoc
mixin _$AntigravityNormalizedUpdateDto {

 String? get title; AntigravityNormalizedToolKind? get kind; Object? get rawInput; Object? get rawOutput; List<Object?>? get content;@JsonKey(name: "_meta") Object? get metadata;

  /// Serializes this AntigravityNormalizedUpdateDto to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable(createFactory: false)

class _AntigravityNormalizedUpdateDto implements AntigravityNormalizedUpdateDto {
  const _AntigravityNormalizedUpdateDto({required this.title, required this.kind, required this.rawInput, required this.rawOutput, required  List<Object?>? content, @JsonKey(name: "_meta") required this.metadata}): _content = content;
  

@override final  String? title;
@override final  AntigravityNormalizedToolKind? kind;
@override final  Object? rawInput;
@override final  Object? rawOutput;
 final  List<Object?>? _content;
@override List<Object?>? get content {
  final value = _content;
  if (value == null) return null;
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: "_meta") final  Object? metadata;


@override
Map<String, dynamic> toJson() {
  return _$AntigravityNormalizedUpdateDtoToJson(this, );
}





}




/// @nodoc
mixin _$AntigravityNormalizedToolFieldsDto {

 String? get command; String? get cwd; String? get stdout; int? get exitCode; String? get imagePath;

  /// Serializes this AntigravityNormalizedToolFieldsDto to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable(createFactory: false)

class _AntigravityNormalizedToolFieldsDto implements AntigravityNormalizedToolFieldsDto {
  const _AntigravityNormalizedToolFieldsDto({required this.command, required this.cwd, required this.stdout, required this.exitCode, required this.imagePath});
  

@override final  String? command;
@override final  String? cwd;
@override final  String? stdout;
@override final  int? exitCode;
@override final  String? imagePath;


@override
Map<String, dynamic> toJson() {
  return _$AntigravityNormalizedToolFieldsDtoToJson(this, );
}





}




AntigravityToolContentDto _$AntigravityToolContentDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'content':
          return AntigravityWrappedToolContentDto.fromJson(
            json
          );
                case 'text':
          return AntigravityTextToolContentDto.fromJson(
            json
          );
        
          default:
            return AntigravityUnknownToolContentDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$AntigravityToolContentDto {



  /// Serializes this AntigravityToolContentDto to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable()

class AntigravityWrappedToolContentDto implements AntigravityToolContentDto {
  const AntigravityWrappedToolContentDto({required this.content,  String? $type}): $type = $type ?? 'content';
  factory AntigravityWrappedToolContentDto.fromJson(Map<String, dynamic> json) => _$AntigravityWrappedToolContentDtoFromJson(json);

 final  AntigravityToolContentDto content;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AntigravityWrappedToolContentDtoToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class AntigravityTextToolContentDto implements AntigravityToolContentDto {
  const AntigravityTextToolContentDto({required this.text,  String? $type}): $type = $type ?? 'text';
  factory AntigravityTextToolContentDto.fromJson(Map<String, dynamic> json) => _$AntigravityTextToolContentDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AntigravityTextToolContentDtoToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class AntigravityUnknownToolContentDto implements AntigravityToolContentDto {
  const AntigravityUnknownToolContentDto({ String? $type}): $type = $type ?? 'unknown';
  factory AntigravityUnknownToolContentDto.fromJson(Map<String, dynamic> json) => _$AntigravityUnknownToolContentDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AntigravityUnknownToolContentDtoToJson(this, );
}





}




// dart format on
