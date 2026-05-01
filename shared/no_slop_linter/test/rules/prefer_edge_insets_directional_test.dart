import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/prefer_edge_insets_directional_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferEdgeInsetsDirectionalTest);
  });
}

@reflectiveTest
class PreferEdgeInsetsDirectionalTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferEdgeInsetsDirectionalRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForEdgeInsetsOnly() async {
    await assertDiagnostics(r'''
class EdgeInsets {
  const EdgeInsets.only({double? left});
}
final padding = EdgeInsets.only(left: 8);
''', [lint(78, 24)]);
  }

  void test_reportForEdgeInsetsFromLTRB() async {
    await assertDiagnostics(r'''
class EdgeInsets {
  const EdgeInsets.fromLTRB(double l, double t, double r, double b);
}
final padding = EdgeInsets.fromLTRB(8, 0, 8, 0);
''', [lint(106, 31)]);
  }

  void test_noErrorForEdgeInsetsAll() async {
    await assertNoDiagnostics(r'''
class EdgeInsets {
  const EdgeInsets.all(double value);
}
final padding = EdgeInsets.all(8);
''');
  }

  void test_noErrorForEdgeInsetsSymmetric() async {
    await assertNoDiagnostics(r'''
class EdgeInsets {
  const EdgeInsets.symmetric({double? horizontal, double? vertical});
}
final padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
''');
  }

  void test_noErrorForEdgeInsetsDirectional() async {
    await assertNoDiagnostics(r'''
class EdgeInsetsDirectional {
  const EdgeInsetsDirectional.only({double? start});
}
final padding = EdgeInsetsDirectional.only(start: 8);
''');
  }

  void test_noErrorForEdgeInsetsOnlyWhenParameterTypeIsEdgeInsets() async {
    await assertNoDiagnostics(r'''
class EdgeInsets {
  const EdgeInsets.only({double? left});
}

class MarkdownText {
  final EdgeInsets padding;
  const MarkdownText({required this.padding});
}

final widget = MarkdownText(padding: EdgeInsets.only(left: 8));
''');
  }

  void test_noErrorForEdgeInsetsFromLTRBWhenParameterTypeIsEdgeInsets() async {
    await assertNoDiagnostics(r'''
class EdgeInsets {
  const EdgeInsets.fromLTRB(double l, double t, double r, double b);
}

void someFunction({required EdgeInsets insets}) {}

void main() {
  someFunction(insets: EdgeInsets.fromLTRB(8, 0, 8, 0));
}
''');
  }
}
