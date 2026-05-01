import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids usage of `Tuple` types from the dartz package.
///
/// Dart 3 introduced native record types which provide the same functionality
/// with better syntax and language integration. Use records instead of Tuple.
///
/// Examples that trigger this rule:
/// - `Tuple2<String, int> pair;`
/// - `Tuple3<String, int, bool> triple;`
/// - `final result = Tuple2('hello', 42);`
///
/// Suggested replacements:
/// - `Tuple2<String, int>` -> `(String, int)`
/// - `Tuple3<String, int, bool>` -> `(String, int, bool)`
/// - `Tuple2('hello', 42)` -> `('hello', 42)`
class AvoidDartzTupleRule extends NoSlopRule {
  AvoidDartzTupleRule({required super.ignoreTestFiles}) : super(name: code.lowerCaseName, description: 'Forbids Tuple from dartz.');

  static const code = LintCode(
    'avoid_dartz_tuple',
    'Avoid using Tuple from dartz. Use Dart 3 records instead.',
    correctionMessage: 'Replace Tuple2<A, B> with (A, B) and Tuple2(a, b) with (a, b).',
  );

  /// Pattern to match Tuple types (Tuple2, Tuple3, etc.)
  static final _tuplePattern = RegExp(r'^Tuple[2-9]$');

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(this);
    registry.addNamedType(this, visitor);
    registry.addInstanceCreationExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidDartzTupleRule rule;

  @override
  void visitNamedType(NamedType node) {
    if (rule.isCurrentFileExcluded) return;
    final typeName = node.name.lexeme;
    if (!AvoidDartzTupleRule._tuplePattern.hasMatch(typeName)) return;

    final element = node.element;
    if (element == null) return;

    final libraryIdentifier = element.library?.identifier;
    if (libraryIdentifier == null) return;
    if (!libraryIdentifier.contains('dartz')) return;

    rule.reportAtNode(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final typeName = node.constructorName.type.name.lexeme;
    if (!AvoidDartzTupleRule._tuplePattern.hasMatch(typeName)) return;

    final element = node.staticType?.element;
    if (element == null) return;

    final libraryIdentifier = element.library?.identifier;
    if (libraryIdentifier == null) return;
    if (!libraryIdentifier.contains('dartz')) return;

    rule.reportAtNode(node);
  }
}
