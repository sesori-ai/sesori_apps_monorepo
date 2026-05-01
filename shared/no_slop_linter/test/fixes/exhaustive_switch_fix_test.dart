import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:no_slop_linter/src/fixes/exhaustive_switch_fix.dart';
import 'package:no_slop_linter/src/rules/prefer_exhaustive_switch_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../test_utils/analysis_rule_fix_test.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ExhaustiveSwitchFixTest);
  });
}

@reflectiveTest
class ExhaustiveSwitchFixTest extends AnalysisRuleFixTest {
  @override
  void setUp() {
    rule = PreferExhaustiveSwitchRule(ignoreTestFiles: false);
    super.setUp();
  }

  // Metadata tests

  void test_combinedFix_hasCorrectFixKind() {
    final fix = ExhaustiveSwitchCombinedFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.fixKind.id, 'no_slop_linter.fix.exhaustiveSwitchCombined');
    expect(fix.fixKind.message, 'Replace with combined case');
  }

  void test_combinedFix_hasSingleLocationApplicability() {
    final fix = ExhaustiveSwitchCombinedFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.applicability, CorrectionApplicability.singleLocation);
  }

  void test_individualFix_hasCorrectFixKind() {
    final fix = ExhaustiveSwitchIndividualFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.fixKind.id, 'no_slop_linter.fix.exhaustiveSwitchIndividual');
    expect(fix.fixKind.message, 'Replace with individual cases');
  }

  void test_individualFix_hasSingleLocationApplicability() {
    final fix = ExhaustiveSwitchIndividualFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.applicability, CorrectionApplicability.singleLocation);
  }

  // Transformation tests

  void test_combinedFix_replacesDefaultWithMissingEnumCases() async {
    await assertHasFix(
      r'''
enum Color { red, green, blue }

String describe(Color c) {
  switch (c) {
    case Color.red:
      return 'red';
    default:
      return 'other';
  }
}
''',
      r'''
enum Color { red, green, blue }

String describe(Color c) {
  switch (c) {
    case Color.red:
      return 'red';
    case .green || .blue:
return 'other';
  }
}
''',
      ExhaustiveSwitchCombinedFix.new,
    );
  }

  void test_individualFix_replacesDefaultWithSeparateEnumCases() async {
    await assertHasFix(
      r'''
enum Color { red, green, blue }

String describe(Color c) {
  switch (c) {
    case Color.red:
      return 'red';
    default:
      return 'other';
  }
}
''',
      r'''
enum Color { red, green, blue }

String describe(Color c) {
  switch (c) {
    case Color.red:
      return 'red';
    case .green:
return 'other';
case .blue:
return 'other';
  }
}
''',
      ExhaustiveSwitchIndividualFix.new,
    );
  }
}
