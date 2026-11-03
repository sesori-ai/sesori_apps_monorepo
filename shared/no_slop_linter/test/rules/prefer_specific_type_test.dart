import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/prefer_specific_type_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferSpecificTypeTest);
  });
}

@reflectiveTest
class PreferSpecificTypeTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferSpecificTypeRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForDynamicVariable() async {
    await assertDiagnostics(
      r'''
dynamic foo;
''',
      [lint(0, 7)],
    );
  }

  void test_reportForDynamicParameter() async {
    await assertDiagnostics(
      r'''
void foo(dynamic x) {}
''',
      [lint(9, 7)],
    );
  }

  void test_reportForDynamicInListGeneric() async {
    await assertDiagnostics(
      r'''
List<dynamic> items = [];
''',
      [lint(5, 7)],
    );
  }

  void test_reportForDynamicAsMapKeyType() async {
    await assertDiagnostics(
      r'''
Map<dynamic, String> map = {};
''',
      [lint(4, 7)],
    );
  }

  void test_reportForDynamicReturnType() async {
    await assertDiagnostics(
      r'''
dynamic foo() => null;
''',
      [lint(0, 7)],
    );
  }

  void test_reportForDynamicInClassField() async {
    await assertDiagnostics(
      r'''
class Foo {
  dynamic bar;
}
''',
      [lint(14, 7)],
    );
  }

  void test_noErrorForMapStringDynamicOutsideFromJson() async {
    await assertNoDiagnostics(r'''
void foo(Map<String, dynamic> json) {}
''');
  }

  void test_noErrorForMapStringDynamicInRegularConstructor() async {
    await assertNoDiagnostics(r'''
class Foo {
  Foo(Map<String, dynamic> json);
}
''');
  }

  void test_noErrorForMapStringDynamicInRegularMethod() async {
    await assertNoDiagnostics(r'''
class Foo {
  static Foo parseJson(Map<String, dynamic> json) => Foo();
}
''');
  }

  void test_reportForNestedDynamicType() async {
    await assertDiagnostics(
      r'''
List<List<dynamic>> nestedList = [];
''',
      [lint(10, 7)],
    );
  }

  void test_noErrorForMapStringDynamicReturnTypeInNonToJson() async {
    await assertNoDiagnostics(r'''
class Foo {
  Map<String, dynamic> serialize() => {};
}
''');
  }

  void test_noErrorForJsonMapTypesAndLiterals() async {
    await assertNoDiagnostics(r'''
typedef JsonMap = Map<String, Object?>;

Map<String, Object?> encode() => <String, Object?>{'a': 1, 'b': <String, dynamic>{}};

bool isJsonObject(Object? json) => json is Map<String, dynamic>;

List<Map<String, Object?>> rows = [];
''');
  }

  void test_reportForNonNullableObjectMapValue() async {
    await assertDiagnostics(
      r'''
Map<String, Object> values = {};
''',
      [lint(12, 6)],
    );
  }

  void test_reportForNonStringKeyedMap() async {
    await assertDiagnostics(
      r'''
Map<Object?, Object?> values = {};
Map<int, dynamic> other = {};
''',
      [lint(4, 7), lint(13, 7), lint(44, 7)],
    );
  }

  void test_noErrorForJsonDecodeCallbackParameters() async {
    await assertNoDiagnostics(r'''
Future<T> get<T>({required T Function(dynamic json) fromJson}) async => fromJson(null);

String parseName(dynamic json) => json is String ? json : '';

String? parseOptionalName(Object? json) => json is String ? json : null;
''');
  }

  void test_reportForDynamicParameterNotNamedJson() async {
    await assertDiagnostics(
      r'''
String parseName(dynamic payload) => '';
''',
      [lint(17, 7)],
    );
  }

  void test_noErrorForFromJsonFactory() async {
    await assertNoDiagnostics(r'''
class Foo {
  factory Foo.fromJson(Map<String, dynamic> json) {
    return Foo();
  }
  Foo();
}
''');
  }

  void test_noErrorForFromJsonStaticMethod() async {
    await assertNoDiagnostics(r'''
class Foo {
  static Foo fromJson(Map<String, dynamic> json) {
    return Foo();
  }
}
''');
  }

  void test_noErrorForFromJsonTopLevelFunction() async {
    await assertNoDiagnostics(r'''
class Foo {}

Foo fromJson(Map<String, dynamic> json) {
  return Foo();
}
''');
  }

  void test_noErrorForExplicitTypes() async {
    await assertNoDiagnostics(r'''
String foo = '';
int bar = 0;
List<String> items = [];
Map<String, int> map = {};
''');
  }

  void test_reportForObjectType() async {
    await assertDiagnostics(
      r'''
Object foo = '';
List<Object> items = [];
''',
      [lint(0, 6), lint(22, 6)],
    );
  }

  void test_reportForNullableObjectType() async {
    await assertDiagnostics(
      r'''
Object? foo;
List<Object?> items = [];
''',
      [lint(0, 7), lint(18, 7)],
    );
  }

  void test_noErrorForToJsonMethod() async {
    await assertNoDiagnostics(r'''
class Foo {
  Map<String, dynamic> toJson() => {};
}
''');
  }

  void test_noErrorForToJsonTopLevelFunction() async {
    await assertNoDiagnostics(r'''
Map<String, dynamic> toJson() => {};
''');
  }

  void test_noErrorForExternalFunctionWithDynamic() async {
    await assertNoDiagnostics(r'''
external dynamic getValue();
external void setValue(dynamic value);
''');
  }

  void test_noErrorForExternalMethodWithDynamic() async {
    await assertNoDiagnostics(r'''
class JsInterop {
  external dynamic getValue();
  external void setValue(dynamic value);
}
''');
  }

  void test_noErrorForExternalFieldWithDynamic() async {
    await assertNoDiagnostics(r'''
class JsInterop {
  external dynamic value;
}
''');
  }

  void test_reportOnlyForBaseClassDynamicParameter() async {
    await assertDiagnostics(
      r'''
abstract class Base {
  void foo(dynamic value);
}

class Child extends Base {
  @override
  void foo(dynamic value) {}
}
''',
      [lint(33, 7)],
    );
  }

  void test_reportOnlyForBaseClassDynamicGenericParameter() async {
    await assertDiagnostics(
      r'''
abstract class Base {
  void foo(List<dynamic> items);
}

class Child extends Base {
  @override
  void foo(List<dynamic> items) {}
}
''',
      [lint(38, 7)],
    );
  }

  void test_noErrorForObjectInCatchClause() async {
    await assertNoDiagnostics(r'''
void foo() {
  try {
    bar();
  } on Object catch (e) {
    print(e);
  }
}
void bar() {}
''');
  }

  void test_noErrorForObjectInOnErrorCallback() async {
    await assertNoDiagnostics(r'''
void foo(Stream<int> stream) {
  stream.listen(
    (event) => print(event),
    onError: (Object error, StackTrace stackTrace) {
      print(error);
    },
  );
}
''');
  }

  void test_noErrorForObjectInFutureCatchError() async {
    await assertNoDiagnostics(r'''
void foo(Future<int> future) {
  future.catchError((Object error, StackTrace stackTrace) {
    return 0;
  });
}
''');
  }

  void test_noErrorForObjectInCallbackArgument() async {
    await assertNoDiagnostics(r'''
void foo(Function callback) {
  callback((Object arg) => print(arg));
}
''');
  }

  void test_noErrorForObjectInOverriddenMethodReturnType() async {
    await assertDiagnostics(
      r'''
abstract class Base {
  Object doSomething();
}

class Child extends Base {
  @override
  Object doSomething() => 'hello';
}
''',
      [lint(24, 6)],
    );
  }

  void test_reportForObjectInOwnFunctionParameter() async {
    await assertDiagnostics(
      r'''
void doSomething({required Object arg}) {}
''',
      [lint(27, 6)],
    );
  }

  void test_noErrorForDynamicInCallbackArgument() async {
    await assertNoDiagnostics(r'''
void foo(Function callback) {
  callback((dynamic arg) => print(arg));
}
''');
  }

  void test_noErrorForObjectAsGenericBound() async {
    await assertNoDiagnostics(r'''
Future<T?> pushRoute<T extends Object?>(int route) {
  return Future.value();
}
''');
  }

  void test_noErrorForObjectNamedError() async {
    await assertNoDiagnostics(r'''
void foo(Object error) {}
''');
  }

  void test_noErrorForObjectNamedSomeError() async {
    await assertNoDiagnostics(r'''
void foo(Object someError) {}
''');
  }

  void test_noErrorForNullableObjectNamedError() async {
    await assertNoDiagnostics(r'''
void foo(Object? error) {}
''');
  }

  void test_reportForDynamicNamedError() async {
    await assertDiagnostics(
      r'''
void foo(dynamic error) {}
''',
      [lint(9, 7)],
    );
  }

  void test_reportForObjectNamedValue() async {
    await assertDiagnostics(
      r'''
void foo(Object value) {}
''',
      [lint(9, 6)],
    );
  }

  void test_noErrorForObjectNamedCause() async {
    await assertNoDiagnostics(r'''
class Failure {
  Failure({required this.cause, required this.innerError, required this.rootCause});

  final Object cause;
  final Object innerError;
  final Object? rootCause;
}

void fail({required Object cause}) {}
''');
  }

  void test_reportForObjectDeclarationMixingCauseAndOtherNames() async {
    await assertDiagnostics(
      r'''
void f() {
  Object value = 1, cause = 2;
}
''',
      [lint(13, 6)],
    );
  }

  void test_noErrorForErrorAndStackTraceHandler() async {
    await assertNoDiagnostics(r'''
class Listener {
  void _onStreamError(Object error, StackTrace stackTrace) {}
}

typedef ErrorHandler = void Function(Object error, StackTrace stackTrace);
''');
  }

  void test_reportForDynamicNamedCause() async {
    await assertDiagnostics(
      r'''
void foo(dynamic cause) {}
''',
      [lint(9, 7)],
    );
  }
}
