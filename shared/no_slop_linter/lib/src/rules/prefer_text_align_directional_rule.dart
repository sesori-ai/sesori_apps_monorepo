import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that enforces directional TextAlign values.
///
/// Using TextAlign.start/end instead of left/right ensures proper
/// RTL (right-to-left) language support.
///
/// Examples that trigger this rule:
/// - `TextAlign.left`
/// - `TextAlign.right`
///
/// Valid examples:
/// - `TextAlign.start` - adapts to text direction
/// - `TextAlign.end` - adapts to text direction
/// - `TextAlign.center` - symmetric, no RTL issue
/// - `TextAlign.justify` - symmetric, no RTL issue
/// - Switch case patterns matching TextAlign values (exhaustive matching)
class PreferTextAlignDirectionalRule extends NoSlopRule {
  PreferTextAlignDirectionalRule({required super.ignoreTestFiles}) : super(name: code.lowerCaseName, description: 'Enforces TextAlign.start/end for RTL support.');

  static const code = LintCode(
    'prefer_text_align_directional',
    'Use TextAlign.start/end instead of left/right for RTL support.',
    correctionMessage: 'Replace TextAlign.left with TextAlign.start, TextAlign.right with TextAlign.end.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addPrefixedIdentifier(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final PreferTextAlignDirectionalRule rule;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.prefix.name == 'TextAlign') {
      final identifier = node.identifier.name;
      if (identifier == 'left' || identifier == 'right') {
        if (_isInSwitchPattern(node)) return;
        rule.reportAtNode(node);
      }
    }
  }

  bool _isInSwitchPattern(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is SwitchExpressionCase ||
          current is SwitchPatternCase ||
          current is ConstantPattern) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
