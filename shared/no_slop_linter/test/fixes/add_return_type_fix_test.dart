import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:no_slop_linter/src/fixes/add_return_type_fix.dart';
import 'package:no_slop_linter/src/rules/avoid_dynamic_return_type_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../test_utils/analysis_rule_fix_test.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddReturnTypeFixTest);
  });
}

@reflectiveTest
class AddReturnTypeFixTest extends AnalysisRuleFixTest {
  @override
  void setUp() {
    rule = AvoidDynamicReturnTypeRule();
    super.setUp();
  }

  void test_hasCorrectFixKind() {
    final fix = AddReturnTypeFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.fixKind.id, 'no_slop_linter.fix.addReturnType');
    expect(fix.fixKind.message, 'Add explicit return type');
  }

  void test_hasSingleLocationApplicability() {
    final fix = AddReturnTypeFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.applicability, CorrectionApplicability.singleLocation);
  }

  void test_fixesMissingReturnTypeWithIntReturn() async {
    await assertHasFix(
      r'''
foo() {
  return 42;
}
''',
      r'''
int foo() {
  return 42;
}
''',
      AddReturnTypeFix.new,
    );
  }

  void test_fixesVoidFunction() async {
    await assertHasFix(
      r'''
foo() {}
''',
      r'''
void foo() {}
''',
      AddReturnTypeFix.new,
    );
  }
}
