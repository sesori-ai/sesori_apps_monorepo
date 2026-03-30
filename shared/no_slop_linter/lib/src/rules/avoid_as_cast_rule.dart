import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils/no_slop_rule.dart';

/// A lint rule that forbids type casting with `as`.
///
/// All `as` casts can throw TypeError at runtime if the cast fails.
/// Note: `as Type?` is NOT a safe cast - it still throws if types don't match.
/// The `?` only allows null values to pass through, it doesn't prevent throws.
///
/// Use type checks (`is`) with smart casting instead.
///
/// Examples that trigger this rule:
/// - `object as String` - throws if not a String
/// - `object as String?` - still throws if object is non-null and not String
/// - `(list[0] as Widget).build(context)` - force cast
///
/// Valid examples:
/// - `if (object is String) { ... }` - type check with smart cast
/// - `switch (object) { case String s => ... }` - pattern matching
class AvoidAsCastRule extends NoSlopRule {
  AvoidAsCastRule() : super(name: code.lowerCaseName, description: 'Forbids type casting with as.');

  static const code = LintCode(
    'avoid_as_cast',
    "Avoid type casting with 'as'. It can throw TypeError at runtime.",
    correctionMessage: "Use 'is' for type checking with smart cast, or pattern matching.",
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addAsExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidAsCastRule rule;

  @override
  void visitAsExpression(AsExpression node) {
    if (rule.isCurrentFileExcluded) return;
    rule.reportAtNode(node);
  }
}
