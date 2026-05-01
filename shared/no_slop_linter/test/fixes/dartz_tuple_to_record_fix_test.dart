import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:no_slop_linter/src/fixes/dartz_tuple_to_record_fix.dart';
import 'package:no_slop_linter/src/rules/avoid_dartz_tuple_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../test_utils/analysis_rule_fix_test.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DartzTupleToRecordFixTest);
  });
}

@reflectiveTest
class DartzTupleToRecordFixTest extends AnalysisRuleFixTest {
  @override
  void setUp() {
    rule = AvoidDartzTupleRule(ignoreTestFiles: false);
    newPackage('dartz')..addFile('lib/dartz.dart', r'''
class Tuple2<A, B> {
  final A value1;
  final B value2;
  Tuple2(this.value1, this.value2);
}

class Tuple3<A, B, C> {
  final A value1;
  final B value2;
  final C value3;
  Tuple3(this.value1, this.value2, this.value3);
}
''');
    super.setUp();
  }

  // Metadata tests

  void test_hasCorrectFixKind() {
    final fix = DartzTupleToRecordFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.fixKind.id, 'no_slop_linter.fix.dartzTupleToRecord');
    expect(fix.fixKind.message, 'Convert to Dart record');
  }

  void test_hasSingleLocationApplicability() {
    final fix = DartzTupleToRecordFix(
      context: StubCorrectionProducerContext.instance,
    );
    expect(fix.applicability, CorrectionApplicability.singleLocation);
  }

  // Transformation tests

  void test_convertsTuple2TypeToRecord() async {
    await assertHasFix(
      r'''
import 'package:dartz/dartz.dart';

Tuple2<String, int> getPair() => Tuple2('hello', 42);
''',
      r'''
import 'package:dartz/dartz.dart';

(String, int) getPair() => Tuple2('hello', 42);
''',
      DartzTupleToRecordFix.new,
    );
  }

  void test_convertsTuple2InstanceToRecord() async {
    await assertHasFix(
      r'''
import 'package:dartz/dartz.dart';

final pair = Tuple2('hello', 42);
''',
      r'''
import 'package:dartz/dartz.dart';

final pair = ('hello', 42);
''',
      DartzTupleToRecordFix.new,
    );
  }
}
