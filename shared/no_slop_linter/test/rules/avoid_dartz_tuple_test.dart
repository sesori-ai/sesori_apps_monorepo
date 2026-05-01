import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/utils/no_slop_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_dartz_tuple_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidDartzTupleTest);
  });
}

@reflectiveTest
class AvoidDartzTupleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidDartzTupleRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_noErrorForCustomTuple2Class() async {
    await assertNoDiagnostics(r'''
class Tuple2<A, B> {
  final A value1;
  final B value2;
  Tuple2(this.value1, this.value2);
}

Tuple2<String, int> getPair() => Tuple2('hello', 42);
''');
  }

  void test_noErrorForCustomTuple3Class() async {
    await assertNoDiagnostics(r'''
class Tuple3<A, B, C> {
  final A value1;
  final B value2;
  final C value3;
  Tuple3(this.value1, this.value2, this.value3);
}

Tuple3<String, int, bool> getTriple() => Tuple3('a', 1, true);
''');
  }

  void test_noErrorForTuple1() async {
    await assertNoDiagnostics(r'''
class Tuple1<A> {
  final A value;
  Tuple1(this.value);
}

Tuple1<String> getSingle() => Tuple1('hello');
''');
  }

  void test_noErrorForClassWithTupleInName() async {
    await assertNoDiagnostics(r'''
class MyTuple2Data {
  final String name;
  MyTuple2Data(this.name);
}

void main() {
  final data = MyTuple2Data('test');
  print(data);
}
''');
  }

  void test_noErrorForRegularRecords() async {
    await assertNoDiagnostics(r'''
(String, int) getPair() => ('hello', 42);

void main() {
  final pair = ('hello', 42);
  print(pair);
}
''');
  }
}
