import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:no_slop_linter/src/fixes/required_named_parameters_fix.dart';
import 'package:no_slop_linter/src/rules/prefer_required_named_parameters_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../test_utils/analysis_rule_fix_test.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RequiredNamedParamsFixTest);
  });
}

@reflectiveTest
class RequiredNamedParamsFixTest extends AnalysisRuleFixTest {
  @override
  void setUp() {
    rule = PreferRequiredNamedParametersRule();
    super.setUp();
  }

  // Metadata tests

  void test_allNamedFix_hasCorrectFixKind() {
    final fix = RequiredNamedParamsAllNamedFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.fixKind.id, 'no_slop_linter.fix.requiredNamedParamsAllNamed');
    expect(fix.fixKind.message, 'Convert all positional params to required named');
  }

  void test_allNamedFix_hasSingleLocationApplicability() {
    final fix = RequiredNamedParamsAllNamedFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.applicability, CorrectionApplicability.singleLocation);
  }

  void test_keepFirstFix_hasCorrectFixKind() {
    final fix = RequiredNamedParamsKeepFirstFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.fixKind.id, 'no_slop_linter.fix.requiredNamedParamsKeepFirst');
    expect(fix.fixKind.message, 'Keep first positional, convert rest to required named');
  }

  void test_keepFirstFix_hasSingleLocationApplicability() {
    final fix = RequiredNamedParamsKeepFirstFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.applicability, CorrectionApplicability.singleLocation);
  }

  void test_addRequiredFix_hasCorrectFixKind() {
    final fix = RequiredNamedParamsAddRequiredFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.fixKind.id, 'no_slop_linter.fix.requiredNamedParamsAddRequired');
    expect(fix.fixKind.message, 'Add required to nullable params');
  }

  void test_addRequiredFix_hasSingleLocationApplicability() {
    final fix = RequiredNamedParamsAddRequiredFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.applicability, CorrectionApplicability.singleLocation);
  }

  // Transformation tests

  void test_allNamedFix_convertsPositionalToNamed() async {
    await assertHasFix(
      r'''
void foo(String a, int b) {}
''',
      r'''
void foo({required String a, required int b}) {}
''',
      RequiredNamedParamsAllNamedFix.new,
    );
  }

  void test_keepFirstFix_keepsFirstPositional() async {
    await assertHasFix(
      r'''
void foo(String a, int b, bool c) {}
''',
      r'''
void foo(String a, {required int b, required bool c}) {}
''',
      RequiredNamedParamsKeepFirstFix.new,
    );
  }

  void test_addRequiredFix_addsRequiredToNullable() async {
    await assertHasFix(
      r'''
void foo(String a, {int? b}) {}
''',
      r'''
void foo(String a, {required int? b}) {}
''',
      RequiredNamedParamsAddRequiredFix.new,
    );
  }
}
