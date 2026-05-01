import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/utils/no_slop_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_dynamic_type_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidDynamicTypeTest);
  });
}

@reflectiveTest
class AvoidDynamicTypeTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidDynamicTypeRule(ignoreTestFiles: false);
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

  void test_reportForMapStringDynamicOutsideFromJson() async {
    await assertDiagnostics(
      r'''
void foo(Map<String, dynamic> json) {}
''',
      [lint(21, 7)],
    );
  }

  void test_reportForMapStringDynamicInRegularConstructor() async {
    await assertDiagnostics(
      r'''
class Foo {
  Foo(Map<String, dynamic> json);
}
''',
      [lint(30, 7)],
    );
  }

  void test_reportForMapStringDynamicInRegularMethod() async {
    await assertDiagnostics(
      r'''
class Foo {
  static Foo parseJson(Map<String, dynamic> json) => Foo();
}
''',
      [lint(47, 7)],
    );
  }

  void test_reportForNestedDynamicType() async {
    await assertDiagnostics(
      r'''
List<List<dynamic>> nestedList = [];
''',
      [lint(10, 7)],
    );
  }

  void test_reportForMapStringDynamicReturnTypeInNonToJson() async {
    await assertDiagnostics(
      r'''
class Foo {
  Map<String, dynamic> serialize() => {};
}
''',
      [lint(26, 7)],
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
}
