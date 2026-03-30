// The entrypoint for the no_slop_linter analysis server plugin.
//
// This package provides analyzer plugin rules including:
// - `avoid_bang_operator`: Prevents usage of the null assertion operator (`!`)
// - `avoid_implicit_tostring`: Prevents implicit toString() in string interpolation
// - `avoid_dynamic_return_type`: Prevents implicit/dynamic return types on functions
// - `avoid_dynamic_type`: Forbids usage of `dynamic` type (except fromJson/toJson)
// - `avoid_hardcoded_colors`: Forbids Color() and Colors.xxx, use theme colorScheme
// - `avoid_hardcoded_text_styles`: Forbids TextStyle(), use theme textTheme
// - `avoid_navigator_of`: Forbids Navigator.of(), use AutoRoute
// - `avoid_as_cast`: Forbids force casts, use `is` or `as Type?`
// - `avoid_mutable_class_fields`: Forbids non-final fields, use final
// - `avoid_string_literals_in_widgets`: Forbids hardcoded strings in Text()
// - `avoid_dartz_tuple`: Forbids Tuple from dartz, use Dart 3 records
// - `prefer_edge_insets_directional`: Enforces EdgeInsetsDirectional for RTL
// - `prefer_text_align_directional`: Enforces TextAlign.start/end for RTL
// - `prefer_size_const`: Enforces SizeConst for spacing values
// - `prefer_required_named_parameters`: Enforces required named params for multi-arg functions
// - `prefer_exhaustive_switch`: Forbids default case in switch statements

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/plugin_server.dart' show PluginServer;
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/registry.dart' show PluginRegistryImpl;

import 'src/fixes/add_return_type_fix.dart';
import 'src/fixes/dartz_tuple_to_record_fix.dart';
import 'src/fixes/exhaustive_switch_fix.dart';
import 'src/fixes/required_named_parameters_fix.dart';
import 'src/rules/avoid_as_cast_rule.dart';
import 'src/rules/avoid_bang_operator_rule.dart';
import 'src/rules/avoid_dartz_tuple_rule.dart';
import 'src/rules/avoid_dynamic_return_type_rule.dart';
import 'src/rules/avoid_dynamic_type_rule.dart';
import 'src/rules/avoid_hardcoded_colors_rule.dart';
import 'src/rules/avoid_hardcoded_text_styles_rule.dart';
import 'src/rules/avoid_implicit_tostring_rule.dart';
import 'src/rules/avoid_mutable_class_fields_rule.dart';
import 'src/rules/avoid_navigator_of_rule.dart';
import 'src/rules/avoid_string_literals_in_widgets_rule.dart';
import 'src/rules/prefer_edge_insets_directional_rule.dart';
import 'src/rules/prefer_exhaustive_switch_rule.dart';
import 'src/rules/prefer_required_named_parameters_rule.dart';
import 'src/rules/prefer_size_const_rule.dart';
import 'src/rules/prefer_text_align_directional_rule.dart';

/// The analysis server plugin instance.
final plugin = _NoSlopLinterPlugin();

class _NoSlopLinterPlugin extends Plugin {
  @override
  String get name => 'no_slop_linter';

  @override
  void register(PluginRegistry registry) {
    // Warning rules (enabled by default)
    registry.registerWarningRule(AvoidAsCastRule());
    registry.registerWarningRule(AvoidBangOperatorRule());
    registry.registerWarningRule(AvoidDartzTupleRule());
    registry.registerWarningRule(AvoidDynamicReturnTypeRule());
    registry.registerWarningRule(AvoidDynamicTypeRule());
    registry.registerWarningRule(AvoidImplicitTostringRule());
    registry.registerWarningRule(AvoidMutableClassFieldsRule());
    registry.registerWarningRule(AvoidNavigatorOfRule());
    registry.registerWarningRule(AvoidStringLiteralsInWidgetsRule());
    registry.registerWarningRule(PreferEdgeInsetsDirectionalRule());
    registry.registerWarningRule(PreferExhaustiveSwitchRule());
    registry.registerWarningRule(PreferRequiredNamedParametersRule());
    registry.registerWarningRule(PreferSizeConstRule());
    registry.registerWarningRule(PreferTextAlignDirectionalRule());

    // Lint rules (disabled by default, must be enabled in analysis_options.yaml)
    registry.registerLintRule(AvoidHardcodedColorsRule());
    registry.registerLintRule(AvoidHardcodedTextStylesRule());

    // Fixes
    registry.registerFixForRule(AvoidDynamicReturnTypeRule.code, AddReturnTypeFix.new);
    registry.registerFixForRule(AvoidDartzTupleRule.code, DartzTupleToRecordFix.new);
    registry.registerFixForRule(PreferExhaustiveSwitchRule.code, ExhaustiveSwitchCombinedFix.new);
    registry.registerFixForRule(PreferExhaustiveSwitchRule.code, ExhaustiveSwitchIndividualFix.new);
    registry.registerFixForRule(
      PreferRequiredNamedParametersRule.codePositionalParams,
      RequiredNamedParamsAllNamedFix.new,
    );
    registry.registerFixForRule(
      PreferRequiredNamedParametersRule.codePositionalParams,
      RequiredNamedParamsKeepFirstFix.new,
    );
    registry.registerFixForRule(
      PreferRequiredNamedParametersRule.codeMissingRequired,
      RequiredNamedParamsAddRequiredFix.new,
    );

    // Workaround: The old PluginServer() constructor stores registries with
    // numeric keys (e.g., '0'), which the ignore suggestion's _code getter
    // skips. This means auto-generated ignore comments lack the plugin name
    // prefix, making them ineffective. Adding a named entry ensures that:
    // 1. Ignore suggestions generate "// ignore: no_slop_linter/rule_name"
    // 2. Those comments correctly suppress the diagnostic
    // This is a no-op when PluginServer.new2() is used (named key exists).
    if (registry is PluginRegistryImpl) {
      PluginServer.registries.putIfAbsent(name.toLowerCase(), () => registry);
    }
  }
}
