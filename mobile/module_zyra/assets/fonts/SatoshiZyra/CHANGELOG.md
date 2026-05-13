# Satoshi Zyra Changelog

Based on Satoshi v2.000 by Indian Type Foundry.

## 2.3

- Fixed OpenType `GDEF`/`GPOS` mark classification for spacing accent glyphs across all weights. This restores normal advance width for spacing accents such as backtick/grave (`\``), diaeresis, macron, cedilla, circumflex, caron, breve, dot above, ring, ogonek, tilde, and double acute, which previously overlapped adjacent characters in shaping engines like HarfBuzz/Flutter.
- Bumped internal font version metadata to `2.300` across all shipped OTFs.

## 2.2

- Fixed incorrect OTF internal headers for BlackItalic, LightItalic, and MediumItalic font files that were missing italic style metadata (head.macStyle, OS/2.fsSelection, name subfamily). This caused a race condition in Flutter WASM/SKWasm builds where the italic font variant could be incorrectly picked as the non-italic one (https://github.com/flutter/flutter/issues/178053)

## 2.1

- Reduced kerning for `seven + comma/period/ellipsis` and `comma/period/ellipsis + one` pairs by 45% across all weights to fix visually collapsed spacing in number displays (e.g. "7.5", "0.1", "7,500")
- Renamed font family from "Satoshi" to "Satoshi Zyra" to distinguish patched version
