import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_mutable_class_fields_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidMutableClassFieldsTest);
  });
}

@reflectiveTest
class AvoidMutableClassFieldsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidMutableClassFieldsRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForPublicNonFinalField() async {
    await assertDiagnostics(r'''
class Foo {
  String name;
  Foo(this.name);
}
''', [lint(14, 12)]);
  }

  void test_reportForPublicLateNonFinalField() async {
    await assertDiagnostics(r'''
class Foo {
  late String name;
}
''', [lint(14, 17)]);
  }

  void test_noErrorForFinalField() async {
    await assertNoDiagnostics(r'''
class Foo {
  final String name;
  Foo(this.name);
}
''');
  }

  void test_noErrorForConstField() async {
    await assertNoDiagnostics(r'''
class Foo {
  static const String name = 'foo';
}
''');
  }

  void test_noErrorForStaticField() async {
    await assertNoDiagnostics(r'''
class Foo {
  static int counter = 0;
}
''');
  }

  void test_noErrorForPrivateMutableField() async {
    await assertNoDiagnostics(r'''
class Foo {
  String _name;
  Foo(this._name);
}
''');
  }

  void test_noErrorForPrivateLateMutableField() async {
    await assertNoDiagnostics(r'''
class Foo {
  late String _value;
}
''');
  }

  void test_noErrorForPublicMutableFieldInPrivateClass() async {
    await assertNoDiagnostics(r'''
class _PrivateClass {
  String publicField;
  int anotherPublicField;

  _PrivateClass(this.publicField, this.anotherPublicField);
}
''');
  }

  void test_noErrorForLatePublicMutableFieldInPrivateClass() async {
    await assertNoDiagnostics(r'''
class _InternalState {
  late String value;
  late int count;
}
''');
  }
}
