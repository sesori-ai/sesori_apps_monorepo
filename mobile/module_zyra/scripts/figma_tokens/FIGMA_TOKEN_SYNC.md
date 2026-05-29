# Figma Token Sync

Extracts design token variables (colors, spacing, radius, dimensions) from the Figma Design System file and generates Dart token files.

## Prerequisites

- Access to the VESPR Figma Design System file (file key: `8CQtJDHrN4nxfTPlmCxK9B`)
- Figma Desktop app (for plugin console access)

## Step 1: Export variables from Figma

The Figma REST API's `/variables/local` endpoint requires an Enterprise plan. Since we're on Pro, we use the Figma Plugin API via the console instead.

1. Open the Design System file in **Figma Desktop**
2. Go to **Plugins > Development > Open console**
3. Paste and run the following script:

```js
(async () => {
  const collections = await figma.variables.getLocalVariableCollectionsAsync();

  // Build id → variable lookup for alias resolution (local variables)
  const allVars = {};
  for (const c of collections) {
    for (const id of c.variableIds) {
      const v = await figma.variables.getVariableByIdAsync(id);
      allVars[v.id] = v;
    }
  }

  // Helper: resolve a variable by id, fetching external library vars on demand
  async function getVar(id) {
    if (allVars[id]) return allVars[id];
    try {
      const v = await figma.variables.getVariableByIdAsync(id);
      if (v) { allVars[v.id] = v; return v; }
    } catch (_) {}
    return null;
  }

  // Helper: resolve an alias chain to a final value (COLOR → RGBA, FLOAT → number)
  // modeId is used to pick the correct mode when the referenced variable has
  // multiple modes (e.g., semantic → semantic alias within Color modes).
  // Falls back to the first available mode for single-mode collections (Primitives).
  async function resolveAlias(val, modeId) {
    let ref = await getVar(val.id);
    let refName = ref?.name ?? null;
    let resolved = ref?.valuesByMode;
    resolved = resolved ? (resolved[modeId] ?? Object.values(resolved)[0]) : null;
    while (resolved && resolved.type === 'VARIABLE_ALIAS') {
      const next = await getVar(resolved.id);
      resolved = next?.valuesByMode;
      resolved = resolved ? (resolved[modeId] ?? Object.values(resolved)[0]) : null;
    }
    return { resolved, refName };
  }

  const result = {};
  for (const c of collections) {
    const vars = [];
    for (const id of c.variableIds) {
      const v = allVars[id];
      if (!['COLOR', 'FLOAT'].includes(v.resolvedType)) continue;

      const entry = { name: v.name, resolvedType: v.resolvedType, valuesByMode: {} };
      for (const [modeId, val] of Object.entries(v.valuesByMode)) {
        if (val.type === 'VARIABLE_ALIAS') {
          const { resolved, refName } = await resolveAlias(val, modeId);
          if (resolved != null && typeof resolved === 'object' && 'r' in resolved) {
            // COLOR alias → resolved RGBA + reference name
            entry.valuesByMode[modeId] = {
              r: resolved.r, g: resolved.g, b: resolved.b, a: resolved.a,
              _alias: refName,
            };
          } else if (resolved != null) {
            // FLOAT alias → resolved value + reference name
            entry.valuesByMode[modeId] = { value: resolved, _alias: refName };
          } else {
            entry.valuesByMode[modeId] = val; // unresolvable alias
          }
        } else if (typeof val === 'object' && val != null && 'r' in val) {
          // Direct COLOR value
          entry.valuesByMode[modeId] = { r: val.r, g: val.g, b: val.b, a: val.a };
        } else {
          // Direct FLOAT value (just a number)
          entry.valuesByMode[modeId] = val;
        }
      }
      vars.push(entry);
    }
    result[c.name] = { modes: c.modes, variables: vars };
  }
  console.log(JSON.stringify(result, null, 2));
})();
```

1. Copy the JSON output from the console
2. Save it to `scripts/figma_tokens/figma_tokens.json`

## Step 2: Generate Dart files

```bash
dart run scripts/figma_tokens/sync_figma_tokens.dart generate
```

This reads `scripts/figma_tokens/figma_tokens.json` and generates:

| File | Purpose |
|---|---|
| `lib/theme/primitives/zyra_color_primitives.g.dart` | Mode-invariant base palette (`ZyraColorPrimitives`) |
| `lib/theme/primitives/zyra_colors.g.dart` | Dark/Light semantic tokens (`ZyraColorsDark`, `ZyraColorsLight`, `ZyraColors`) |

## Expected JSON structure

The exported JSON contains variable collections. Each collection has `modes` and `variables` arrays. Each variable includes a `resolvedType` field (`"COLOR"` or `"FLOAT"`).

### Color collections

- **Primitives** — single mode, base color palette (e.g. `Colors/Brand Blue/500`). Values are always direct RGBA.
- **Color Modes** — two modes (Dark/Light), semantic tokens that alias into primitives (e.g. `Colors/Text/text-primary (900)`).

Color values:

- Direct RGBA: `{ "r": 0.04, "g": 0.05, "b": 0.07, "a": 1 }`
- Resolved alias: `{ "r": 0.04, ..., "_alias": "Colors/Gray (light mode)/900" }`

### Numeric collections

- **Spacing** — single mode, spacing scale values.
- **Radius** — single mode, border radius values.
- **Widths** — single mode, width dimension values.
- **Containers** — single mode, container dimension values.

Numeric values:

- Direct: just a number (e.g. `4`, `16`)
- Resolved alias: `{ "value": 4, "_alias": "Spacing/xxs" }`

The `_alias` field tracks which variable another references, allowing the generated Dart code to use constant references instead of inline values.
