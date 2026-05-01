import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/utils/no_slop_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_dynamic_return_type_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidDynamicReturnTypeTest);
  });
}

@reflectiveTest
class AvoidDynamicReturnTypeTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidDynamicReturnTypeRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForImplicitReturnType() async {
    await assertDiagnostics(r'''
foo() {
  return 'hello';
}
''', [lint(0, 27)]);
  }

  void test_reportForExplicitDynamicReturnType() async {
    await assertDiagnostics(r'''
dynamic bar() {
  return 42;
}
''', [lint(0, 7)]);
  }

  void test_reportForMethodWithImplicitReturnType() async {
    await assertDiagnostics(r'''
class TestClass {
  getValue() {
    return 'value';
  }
}
''', [lint(20, 36)]);
  }

  void test_reportForGetterWithImplicitReturnType() async {
    await assertDiagnostics(r'''
class TestClass {
  final String _value = 'test';
  get value => _value;
}
''', [lint(52, 20)]);
  }

  void test_noErrorForVoidReturnType() async {
    await assertNoDiagnostics(r'''
void baz() {
  print('hello');
}
''');
  }

  void test_noErrorForExplicitReturnTypes() async {
    await assertNoDiagnostics(r'''
String qux() {
  return 'hello';
}

int quux() {
  return 42;
}

Future<void> asyncVoid() async {}

Future<int> asyncInt() async {
  return 42;
}
''');
  }

  void test_noErrorForMethodWithExplicitReturnType() async {
    await assertNoDiagnostics(r'''
class TestClass {
  String getName() {
    return 'name';
  }

  String get name => 'name';
}
''');
  }

  void test_noErrorForSetter() async {
    await assertNoDiagnostics(r'''
class TestClass {
  String _value = '';

  set value(String newValue) => _value = newValue;
}
''');
  }

  void test_noErrorForSetterWithComplexExpression() async {
    await assertNoDiagnostics(r'''
typedef ErrorHandler = void Function(Object event);

class TestClass {
  ErrorHandler? _onerror;

  set onerror(ErrorHandler? fn) => _onerror = fn;
}
''');
  }

  void test_noErrorForExternalFunction() async {
    await assertNoDiagnostics(r'''
external dynamic getValue();
external foo();
''');
  }

  void test_noErrorForExternalMethod() async {
    await assertNoDiagnostics(r'''
class JsInterop {
  external dynamic getValue();
  external getBar();
}
''');
  }
}
