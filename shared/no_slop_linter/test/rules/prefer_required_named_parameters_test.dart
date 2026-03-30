import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/prefer_required_named_parameters_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferRequiredNamedParametersTest);
  });
}

@reflectiveTest
class PreferRequiredNamedParametersTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferRequiredNamedParametersRule();
    super.setUp();
  }

  void test_reportForMultiplePositionalParameters() async {
    await assertDiagnostics(r'''
void foo(String a, int b) {}
''', [lint(8, 17)]);
  }

  void test_reportForThreePositionalParametersInMethod() async {
    await assertDiagnostics(r'''
class Foo {
  void bar(String a, int b, bool c) {}
}
''', [lint(22, 25)]);
  }

  void test_reportForMultiplePositionalInConstructor() async {
    await assertDiagnostics(r'''
class Foo {
  Foo(String a, int b);
}
''', [lint(17, 17)]);
  }

  void test_reportForNamedParamWithoutRequiredAndNoDefault() async {
    await assertDiagnostics(r'''
void foo(String a, {int? b}) {}
''', [lint(8, 20)]);
  }

  void test_reportForMixedRequiredAndNotRequired() async {
    await assertDiagnostics(r'''
void foo({required String a, int? b}) {}
''', [lint(8, 29)]);
  }

  void test_reportForAbstractMethodWithNullableNamedParams() async {
    await assertDiagnostics(r'''
abstract interface class Encrypter {
  String encrypt({String? data, String? key});
}
''', [lint(53, 29)]);
  }

  void test_noErrorForSinglePositionalParameter() async {
    await assertNoDiagnostics(r'''
void foo(String name) {}
''');
  }

  void test_noErrorForOnePositionalAndRequiredNamed() async {
    await assertNoDiagnostics(r'''
void foo(String a, {required int b, required bool c}) {}
''');
  }

  void test_noErrorForOnePositionalAndNamedWithDefault() async {
    await assertNoDiagnostics(r'''
void foo(String a, {int b = 0}) {}
''');
  }

  void test_noErrorForAllRequiredNamed() async {
    await assertNoDiagnostics(r'''
void foo({required String a, required int b}) {}
''');
  }

  void test_noErrorForRequiredNullableNamed() async {
    await assertNoDiagnostics(r'''
void foo({required String? a, required int? b}) {}
''');
  }

  void test_noErrorForNamedWithDefaultValue() async {
    await assertNoDiagnostics(r'''
void foo({required String a, int b = 0}) {}
''');
  }

  void test_noErrorForConstructorWithRequiredNamed() async {
    await assertNoDiagnostics(r'''
class Foo {
  Foo({required String a, required int b});
}
''');
  }

  void test_noErrorForOverriddenMethod() async {
    await assertNoDiagnostics(r'''
abstract class Base {
  void bar({required String a, required int b});
}
class Impl extends Base {
  @override
  void bar({required String a, required int b}) {}
}
''');
  }

  void test_noErrorForAbstractMethodWithNonNullableNamedParams() async {
    await assertNoDiagnostics(r'''
abstract interface class Encrypter {
  String encrypt({String data, String key});
}
''');
  }

  void test_noErrorForNoParameters() async {
    await assertNoDiagnostics(r'''
void foo() {}
''');
  }

  void test_noErrorForConstructorWithSuperParameters() async {
    await assertNoDiagnostics(r'''
class Parent {
  final String? key;
  const Parent({this.key});
}
class Child extends Parent {
  final double value;
  const Child({
    super.key,
    required this.value,
  });
}
''');
  }

  void test_noErrorForLazySingletonAnnotatedClass() async {
    await assertNoDiagnostics(r'''
const lazySingleton = Object();

@lazySingleton
class PoolApi {
  final String client;
  final String baseUrl;

  PoolApi(this.client, this.baseUrl);
}
''');
  }

  void test_noErrorForInjectableAnnotatedClass() async {
    await assertNoDiagnostics(r'''
const injectable = Object();

@injectable
class MyService {
  final String dep1;
  final String dep2;
  final String dep3;

  MyService(this.dep1, this.dep2, this.dep3);
}
''');
  }

  void test_noErrorForSingletonAnnotatedClass() async {
    await assertNoDiagnostics(r'''
const singleton = Object();

@singleton
class AppConfig {
  final String apiKey;
  final String baseUrl;

  AppConfig(this.apiKey, this.baseUrl);
}
''');
  }

  void test_noErrorForNullableFunctionTypeCallbackParameters() async {
    await assertNoDiagnostics(r'''
void subscribe({
  required String topic,
  void Function()? onCancel,
  void Function(String error)? onError,
}) {}
''');
  }

  void test_noErrorForMixedRequiredAndNullableCallbackParameters() async {
    await assertNoDiagnostics(r'''
class StreamController {
  StreamController({
    required void Function() onListen,
    void Function()? onPause,
    void Function()? onResume,
    void Function()? onCancel,
  });
}
''');
  }

  void test_noErrorForQueryParamAnnotatedParameters() async {
    await assertNoDiagnostics(r'''
class QueryParam {
  const QueryParam();
}

class DiscoverPage {
  final String? uri;
  final String? timestamp;

  const DiscoverPage({
    @QueryParam() this.uri,
    @QueryParam() this.timestamp,
  });
}
''');
  }

  void test_noErrorForMixedQueryParamAndRequiredParameters() async {
    await assertNoDiagnostics(r'''
class QueryParam {
  const QueryParam();
}

class SearchPage {
  final String query;
  final String? filter;
  final int? page;

  const SearchPage({
    required this.query,
    @QueryParam() this.filter,
    @QueryParam() this.page,
  });
}
''');
  }

  void test_noErrorForNonNullableNamedParamsWithoutRequired() async {
    await assertNoDiagnostics(r'''
abstract class Foo {
  void bar({String a, int b});
}
''');
  }

  void test_noErrorForFreezedStyleDefaultAnnotation() async {
    await assertNoDiagnostics(r'''
class Default {
  final Object value;
  const Default(this.value);
}

class SignMessageState {
  final String host;
  final bool showPayload;

  const SignMessageState({
    required this.host,
    @Default(false) this.showPayload = false,
  });
}
''');
  }

  void test_noErrorForPragmaAnnotatedFunction() async {
    await assertNoDiagnostics(r'''
class pragma {
  final String name;
  const pragma(this.name);
}

@pragma("vm:prefer-inline")
@pragma("dart2js:tryInline")
Future<int> parseJson(String json, int Function(String) parser) =>
    Future.value(parser(json));
''');
  }

  void test_noErrorForPragmaAnnotatedMethod() async {
    await assertNoDiagnostics(r'''
class pragma {
  final String name;
  const pragma(this.name);
}

class Parser {
  @pragma("vm:prefer-inline")
  int parse(String json, int Function(String) converter) => converter(json);
}
''');
  }

  void test_noErrorForEnumConstructorWithPositionalParameters() async {
    await assertNoDiagnostics(r'''
enum StorageType {
  main("main"),
  fallback("fallback");

  final String debugName;

  const StorageType(this.debugName);
}
''');
  }

  void test_noErrorForEnumConstructorWithMultiplePositionalParameters() async {
    await assertNoDiagnostics(r'''
enum Priority {
  low(1, "Low"),
  medium(2, "Medium"),
  high(3, "High");

  final int value;
  final String label;

  const Priority(this.value, this.label);
}
''');
  }
}
