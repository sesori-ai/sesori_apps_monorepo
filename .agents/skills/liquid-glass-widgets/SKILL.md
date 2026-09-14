---
name: liquid-glass-widgets
description: >-
  Use when writing or reviewing Sesori Flutter liquid-glass controls, setup,
  quality policy, or transitions. Includes the published 1.5.0 consumer guide.
---

# Liquid Glass Widgets in Sesori

Read `references/upstream-1.5.0.md` for the official consumer guidance.
Repository instructions and the approved task scope take precedence over its
blanket substitution rules and performance claims:

- Keep glass in the navigation/control layer; do not replace solid content,
  flat product menus, or the custom scaffold gradient without explicit scope.
- Sesori caps adaptive quality at standard, permits recovery from minimal,
  and uses `warmUpMode.never` to skip unused premium preload only.
- Preserve Prego reduced motion. Package accessibility defaults stay enabled;
  high contrast is not evidence of the actual iOS Reduce Transparency signal.
- Use public APIs and inspect the pinned package source when guidance differs.
  Widget tests are not GPU/performance or real-device rendering evidence.

## Provenance

`references/upstream-1.5.0.md` is an unmodified copy of
`skills/liquid-glass-widgets/SKILL.md` from the published pub.dev
`liquid_glass_widgets` 1.5.0 archive:
`https://pub.dev/api/archives/liquid_glass_widgets-1.5.0.tar.gz`.
SHA-256: `211e46b46d93b9e97d977be14f86a4ec2e173e279df64b0c84261a164b6103a5`.
