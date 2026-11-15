// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'deliverable_prompt_part.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DeliverablePromptPart {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliverablePromptPart);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DeliverablePromptPart()';
}


}





/// @nodoc


class DeliverablePromptPartText implements DeliverablePromptPart {
  const DeliverablePromptPartText({required this.text});
  

 final  String text;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliverablePromptPartText&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode {
    return Object.hash(runtimeType,text);
}

@override
String toString() {
    return 'DeliverablePromptPart.text(text: $text)';
}


}




/// @nodoc


class DeliverablePromptPartFileUrl implements DeliverablePromptPart {
  const DeliverablePromptPartFileUrl({required this.mime, required this.url, required this.filename});
  

 final  String mime;
 final  String url;
 final  String? filename;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliverablePromptPartFileUrl&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.url, url) || other.url == url)&&(identical(other.filename, filename) || other.filename == filename));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mime,url,filename);
}

@override
String toString() {
    return 'DeliverablePromptPart.fileUrl(mime: $mime, url: $url, filename: $filename)';
}


}




/// @nodoc


class DeliverablePromptPartFileData implements DeliverablePromptPart {
  const DeliverablePromptPartFileData({required this.mime, required this.base64, required this.filename});
  

 final  String mime;
 final  String base64;
 final  String? filename;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliverablePromptPartFileData&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.filename, filename) || other.filename == filename));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mime,base64,filename);
}

@override
String toString() {
    return 'DeliverablePromptPart.fileData(mime: $mime, base64: $base64, filename: $filename)';
}


}




// dart format on
