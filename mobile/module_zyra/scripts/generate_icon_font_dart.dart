/// Generates a Dart file with IconData constants from OTF icon font files.
///
/// Parses the OTF binary format (cmap + post tables) to extract
/// glyph name → codepoint mappings, then generates static const IconData fields.
///
/// Usage:
///   dart run scripts/generate_icon_font_dart.dart \
///     --font-dir assets/fonts/FontAwesome6Pro \
///     --output lib/core/ui/icons/fa6_pro_icons.g.dart \
///     --family-map "FA6Pro-Thin-100.otf:FA6Thin:FA6Thin" \
///     --family-map "FA6Pro-Light-300.otf:FA6Light:FA6Light" \
///     --family-map "FA6Pro-Regular-400.otf:FA6Regular:FA6Regular" \
///     --family-map "FA6Pro-Solid-900.otf:FA6Solid:FA6Solid"
library;

import 'dart:io';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// OTF binary helpers
// ---------------------------------------------------------------------------

int _u16(ByteData d, int o) => d.getUint16(o);
int _u32(ByteData d, int o) => d.getUint32(o);
int _i16(ByteData d, int o) => d.getInt16(o);
int _i32(ByteData d, int o) => d.getInt32(o);

int _uN(ByteData d, int o, int size) {
  var v = 0;
  for (var i = 0; i < size; i++) {
    v = (v << 8) | d.getUint8(o + i);
  }
  return v;
}

String _ascii(ByteData d, int start, int length) {
  final bytes = List<int>.generate(length, (i) => d.getUint8(start + i));
  return String.fromCharCodes(bytes);
}

/// Locate table offsets from the OTF table directory.
Map<String, int> _tableOffsets(ByteData data) {
  final numTables = _u16(data, 4);
  final map = <String, int>{};
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes([
      data.getUint8(rec),
      data.getUint8(rec + 1),
      data.getUint8(rec + 2),
      data.getUint8(rec + 3),
    ]);
    map[tag] = _u32(data, rec + 8);
  }
  return map;
}

// ---------------------------------------------------------------------------
// cmap parsing – returns codepoint → glyphIndex
// ---------------------------------------------------------------------------

Map<int, int> _parseCmap(ByteData data, int offset) {
  final numSubtables = _u16(data, offset + 2);

  // Prefer platform 3 (Windows) encoding 10 (full Unicode) then encoding 1 (BMP).
  int? bestOffset;
  var bestPriority = -1;
  for (var i = 0; i < numSubtables; i++) {
    final rec = offset + 4 + i * 8;
    final platformId = _u16(data, rec);
    final encodingId = _u16(data, rec + 2);
    final subtableOffset = _u32(data, rec + 4);

    var priority = -1;
    if (platformId == 3 && encodingId == 10) {
      priority = 2;
    } else if (platformId == 3 && encodingId == 1) {
      priority = 1;
    } else if (platformId == 0) {
      // Unicode platform – acceptable fallback
      priority = 0;
    }
    if (priority > bestPriority) {
      bestPriority = priority;
      bestOffset = offset + subtableOffset;
    }
  }
  if (bestOffset == null) {
    throw StateError('No suitable cmap subtable found');
  }

  final format = _u16(data, bestOffset);
  if (format == 4) return _cmapFormat4(data, bestOffset);
  if (format == 12) return _cmapFormat12(data, bestOffset);
  throw StateError('Unsupported cmap format: $format');
}

Map<int, int> _cmapFormat4(ByteData data, int off) {
  final segCount = _u16(data, off + 6) ~/ 2;
  final endCodesOff = off + 14;
  final startCodesOff = endCodesOff + segCount * 2 + 2; // +2 for reservedPad
  final idDeltaOff = startCodesOff + segCount * 2;
  final idRangeOffsetOff = idDeltaOff + segCount * 2;

  final result = <int, int>{};
  for (var i = 0; i < segCount; i++) {
    final endCode = _u16(data, endCodesOff + i * 2);
    final startCode = _u16(data, startCodesOff + i * 2);
    final idDelta = _i16(data, idDeltaOff + i * 2);
    final idRangeOffset = _u16(data, idRangeOffsetOff + i * 2);

    if (startCode == 0xFFFF) break;

    for (var c = startCode; c <= endCode; c++) {
      int glyphIndex;
      if (idRangeOffset == 0) {
        glyphIndex = (c + idDelta) & 0xFFFF;
      } else {
        final glyphOff = idRangeOffsetOff + i * 2 + idRangeOffset + (c - startCode) * 2;
        glyphIndex = _u16(data, glyphOff);
        if (glyphIndex != 0) {
          glyphIndex = (glyphIndex + idDelta) & 0xFFFF;
        }
      }
      if (glyphIndex != 0) {
        result[c] = glyphIndex;
      }
    }
  }
  return result;
}

Map<int, int> _cmapFormat12(ByteData data, int off) {
  final numGroups = _u32(data, off + 12);
  final result = <int, int>{};
  for (var i = 0; i < numGroups; i++) {
    final rec = off + 16 + i * 12;
    final startCharCode = _u32(data, rec);
    final endCharCode = _u32(data, rec + 4);
    var startGlyphId = _u32(data, rec + 8);
    for (var c = startCharCode; c <= endCharCode; c++) {
      result[c] = startGlyphId++;
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// post table parsing – returns glyphIndex → name
// ---------------------------------------------------------------------------

Map<int, String> _parsePost(ByteData data, int offset) {
  final version = _i32(data, offset);
  if (version == 0x00020000) return _postFormat2(data, offset);
  if (version == 0x00030000) {
    // Format 3.0 – no glyph names provided in the font.
    return {};
  }
  throw StateError('Unsupported post table version: 0x${version.toRadixString(16)}');
}

/// Standard Macintosh glyph names (first 258 entries in post format 2.0).
const _macGlyphNames = [
  '.notdef',
  '.null',
  'nonmarkingreturn',
  'space',
  'exclam',
  'quotedbl',
  'numbersign',
  'dollar',
  'percent',
  'ampersand',
  'quotesingle',
  'parenleft',
  'parenright',
  'asterisk',
  'plus',
  'comma',
  'hyphen',
  'period',
  'slash',
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'colon',
  'semicolon',
  'less',
  'equal',
  'greater',
  'question',
  'at',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  'bracketleft',
  'backslash',
  'bracketright',
  'asciicircum',
  'underscore',
  'grave',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
  'braceleft',
  'bar',
  'braceright',
  'asciitilde',
  'Adieresis',
  'Aring',
  'Ccedilla',
  'Eacute',
  'Ntilde',
  'Odieresis',
  'Udieresis',
  'aacute',
  'agrave',
  'acircumflex',
  'adieresis',
  'atilde',
  'aring',
  'ccedilla',
  'eacute',
  'egrave',
  'ecircumflex',
  'edieresis',
  'iacute',
  'igrave',
  'icircumflex',
  'idieresis',
  'ntilde',
  'oacute',
  'ograve',
  'ocircumflex',
  'odieresis',
  'otilde',
  'uacute',
  'ugrave',
  'ucircumflex',
  'udieresis',
  'dagger',
  'degree',
  'cent',
  'sterling',
  'section',
  'bullet',
  'paragraph',
  'germandbls',
  'registered',
  'copyright',
  'trademark',
  'acute',
  'dieresis',
  'notequal',
  'AE',
  'Oslash',
  'infinity',
  'plusminus',
  'lessequal',
  'greaterequal',
  'yen',
  'mu',
  'partialdiff',
  'summation',
  'product',
  'pi',
  'integral',
  'ordfeminine',
  'ordmasculine',
  'Omega',
  'ae',
  'oslash',
  'questiondown',
  'exclamdown',
  'logicalnot',
  'radical',
  'florin',
  'approxequal',
  'Delta',
  'guillemotleft',
  'guillemotright',
  'ellipsis',
  'nonbreakingspace',
  'Agrave',
  'Atilde',
  'Otilde',
  'OE',
  'oe',
  'endash',
  'emdash',
  'quotedblleft',
  'quotedblright',
  'quoteleft',
  'quoteright',
  'divide',
  'lozenge',
  'ydieresis',
  'Ydieresis',
  'fraction',
  'currency',
  'guilsinglleft',
  'guilsinglright',
  'fi',
  'fl',
  'daggerdbl',
  'periodcentered',
  'quotesinglbase',
  'quotedblbase',
  'perthousand',
  'Acircumflex',
  'Ecircumflex',
  'Aacute',
  'Edieresis',
  'Egrave',
  'Iacute',
  'Icircumflex',
  'Idieresis',
  'Igrave',
  'Oacute',
  'Ocircumflex',
  'apple',
  'Ograve',
  'Uacute',
  'Ucircumflex',
  'Ugrave',
  'dotlessi',
  'circumflex',
  'tilde',
  'macron',
  'breve',
  'dotaccent',
  'ring',
  'cedilla',
  'hungarumlaut',
  'ogonek',
  'caron',
  'Lslash',
  'lslash',
  'Scaron',
  'scaron',
  'Zcaron',
  'zcaron',
  'brokenbar',
  'Eth',
  'eth',
  'Yacute',
  'yacute',
  'Thorn',
  'thorn',
  'minus',
  'multiply',
  'onesuperior',
  'twosuperior',
  'threesuperior',
  'onehalf',
  'onequarter',
  'threequarters',
  'franc',
  'Gbreve',
  'gbreve',
  'Idotaccent',
  'Scedilla',
  'scedilla',
  'Cacute',
  'cacute',
  'Ccaron',
  'ccaron',
  'dcroat',
];

Map<int, String> _postFormat2(ByteData data, int offset) {
  final numGlyphs = _u16(data, offset + 32);
  final nameIndicesOff = offset + 34;

  // Collect all name indices
  final nameIndices = List<int>.generate(numGlyphs, (i) => _u16(data, nameIndicesOff + i * 2));

  // Read the Pascal string table that follows
  var strOff = nameIndicesOff + numGlyphs * 2;
  final extraNames = <String>[];
  // We need to read enough strings to cover the max index
  final maxExtraIndex = nameIndices.fold<int>(0, (prev, idx) => idx > prev ? idx : prev) - 258;
  for (var i = 0; i <= maxExtraIndex && strOff < data.lengthInBytes; i++) {
    final len = data.getUint8(strOff);
    strOff++;
    final chars = List<int>.generate(len, (j) => data.getUint8(strOff + j));
    extraNames.add(String.fromCharCodes(chars));
    strOff += len;
  }

  final result = <int, String>{};
  for (var glyphIndex = 0; glyphIndex < numGlyphs; glyphIndex++) {
    final idx = nameIndices[glyphIndex];
    String? name;
    if (idx < 258) {
      if (idx < _macGlyphNames.length) name = _macGlyphNames[idx];
    } else {
      final extraIdx = idx - 258;
      if (extraIdx < extraNames.length) name = extraNames[extraIdx];
    }
    if (name != null) result[glyphIndex] = name;
  }
  return result;
}

// ---------------------------------------------------------------------------
// CFF table parsing – fallback glyphIndex → name (for post format 3.0 fonts)
// ---------------------------------------------------------------------------

class _CffIndex {
  final int count;
  final int endOffset;
  final List<int> starts;
  final List<int> endsExclusive;

  const _CffIndex({
    required this.count,
    required this.endOffset,
    required this.starts,
    required this.endsExclusive,
  });
}

_CffIndex _readCffIndex(ByteData data, int offset) {
  final count = _u16(data, offset);
  if (count == 0) {
    return _CffIndex(
      count: 0,
      endOffset: offset + 2,
      starts: [],
      endsExclusive: [],
    );
  }

  final offSize = data.getUint8(offset + 2);
  final offsetsBase = offset + 3;
  final dataBase = offsetsBase + (count + 1) * offSize;
  final relativeOffsets = List<int>.generate(
    count + 1,
    (i) => _uN(data, offsetsBase + i * offSize, offSize),
  );

  final starts = <int>[];
  final endsExclusive = <int>[];
  for (var i = 0; i < count; i++) {
    starts.add(dataBase + relativeOffsets[i] - 1);
    endsExclusive.add(dataBase + relativeOffsets[i + 1] - 1);
  }

  final endOffset = dataBase + relativeOffsets.last - 1;
  return _CffIndex(
    count: count,
    endOffset: endOffset,
    starts: starts,
    endsExclusive: endsExclusive,
  );
}

Map<int, List<num>> _parseCffDict(ByteData data, int start, int endExclusive) {
  final result = <int, List<num>>{};
  final stack = <num>[];
  var i = start;

  while (i < endExclusive) {
    final b0 = data.getUint8(i++);
    if (b0 >= 32 && b0 <= 246) {
      stack.add(b0 - 139);
      continue;
    }
    if (b0 >= 247 && b0 <= 250) {
      final b1 = data.getUint8(i++);
      stack.add((b0 - 247) * 256 + b1 + 108);
      continue;
    }
    if (b0 >= 251 && b0 <= 254) {
      final b1 = data.getUint8(i++);
      stack.add(-((b0 - 251) * 256 + b1 + 108));
      continue;
    }
    if (b0 == 28) {
      stack.add(_i16(data, i));
      i += 2;
      continue;
    }
    if (b0 == 29) {
      stack.add(_i32(data, i));
      i += 4;
      continue;
    }
    if (b0 == 30) {
      final real = StringBuffer();
      var done = false;
      while (i < endExclusive && !done) {
        final b = data.getUint8(i++);
        final n1 = (b >> 4) & 0x0F;
        final n2 = b & 0x0F;
        for (final nibble in [n1, n2]) {
          switch (nibble) {
            case 0x0A:
              real.write('.');
            case 0x0B:
              real.write('E');
            case 0x0C:
              real.write('E-');
            case 0x0E:
              real.write('-');
            case 0x0F:
              done = true;
            default:
              if (nibble <= 9) real.write(nibble);
          }
          if (done) break;
        }
      }
      stack.add(num.tryParse(real.toString()) ?? 0);
      continue;
    }

    final op = b0 == 12 ? (1200 + data.getUint8(i++)) : b0;
    result[op] = List<num>.from(stack);
    stack.clear();
  }
  return result;
}

/// CFF standard string table (SIDs 0-390), from Adobe Tech Note 5176.
const _cffStandardStrings = [
  '.notdef',
  'space',
  'exclam',
  'quotedbl',
  'numbersign',
  'dollar',
  'percent',
  'ampersand',
  'quoteright',
  'parenleft',
  'parenright',
  'asterisk',
  'plus',
  'comma',
  'hyphen',
  'period',
  'slash',
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'colon',
  'semicolon',
  'less',
  'equal',
  'greater',
  'question',
  'at',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  'bracketleft',
  'backslash',
  'bracketright',
  'asciicircum',
  'underscore',
  'quoteleft',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
  'braceleft',
  'bar',
  'braceright',
  'asciitilde',
  'exclamdown',
  'cent',
  'sterling',
  'fraction',
  'yen',
  'florin',
  'section',
  'currency',
  'quotesingle',
  'quotedblleft',
  'guillemotleft',
  'guilsinglleft',
  'guilsinglright',
  'fi',
  'fl',
  'endash',
  'dagger',
  'daggerdbl',
  'periodcentered',
  'paragraph',
  'bullet',
  'quotesinglbase',
  'quotedblbase',
  'quotedblright',
  'guillemotright',
  'ellipsis',
  'perthousand',
  'questiondown',
  'grave',
  'acute',
  'circumflex',
  'tilde',
  'macron',
  'breve',
  'dotaccent',
  'dieresis',
  'ring',
  'cedilla',
  'hungarumlaut',
  'ogonek',
  'caron',
  'emdash',
  'AE',
  'ordfeminine',
  'Lslash',
  'Oslash',
  'OE',
  'ordmasculine',
  'ae',
  'dotlessi',
  'lslash',
  'oslash',
  'oe',
  'germandbls',
  'onesuperior',
  'logicalnot',
  'mu',
  'trademark',
  'Eth',
  'onehalf',
  'plusminus',
  'Thorn',
  'onequarter',
  'divide',
  'brokenbar',
  'degree',
  'thorn',
  'threequarters',
  'twosuperior',
  'registered',
  'minus',
  'eth',
  'multiply',
  'threesuperior',
  'copyright',
  'Aacute',
  'Acircumflex',
  'Adieresis',
  'Agrave',
  'Aring',
  'Atilde',
  'Ccedilla',
  'Eacute',
  'Ecircumflex',
  'Edieresis',
  'Egrave',
  'Iacute',
  'Icircumflex',
  'Idieresis',
  'Igrave',
  'Ntilde',
  'Oacute',
  'Ocircumflex',
  'Odieresis',
  'Ograve',
  'Otilde',
  'Scaron',
  'Uacute',
  'Ucircumflex',
  'Udieresis',
  'Ugrave',
  'Yacute',
  'Ydieresis',
  'Zcaron',
  'aacute',
  'acircumflex',
  'adieresis',
  'agrave',
  'aring',
  'atilde',
  'ccedilla',
  'eacute',
  'ecircumflex',
  'edieresis',
  'egrave',
  'iacute',
  'icircumflex',
  'idieresis',
  'igrave',
  'ntilde',
  'oacute',
  'ocircumflex',
  'odieresis',
  'ograve',
  'otilde',
  'scaron',
  'uacute',
  'ucircumflex',
  'udieresis',
  'ugrave',
  'yacute',
  'ydieresis',
  'zcaron',
  'exclamsmall',
  'Hungarumlautsmall',
  'dollaroldstyle',
  'dollarsuperior',
  'ampersandsmall',
  'Acutesmall',
  'parenleftsuperior',
  'parenrightsuperior',
  'twodotenleader',
  'onedotenleader',
  'zerooldstyle',
  'oneoldstyle',
  'twooldstyle',
  'threeoldstyle',
  'fouroldstyle',
  'fiveoldstyle',
  'sixoldstyle',
  'sevenoldstyle',
  'eightoldstyle',
  'nineoldstyle',
  'commasuperior',
  'threequartersemdash',
  'periodsuperior',
  'questionsmall',
  'asuperior',
  'bsuperior',
  'centsuperior',
  'dsuperior',
  'esuperior',
  'isuperior',
  'lsuperior',
  'msuperior',
  'nsuperior',
  'osuperior',
  'rsuperior',
  'ssuperior',
  'tsuperior',
  'ff',
  'ffi',
  'ffl',
  'parenleftinferior',
  'parenrightinferior',
  'Circumflexsmall',
  'hyphensuperior',
  'Gravesmall',
  'Asmall',
  'Bsmall',
  'Csmall',
  'Dsmall',
  'Esmall',
  'Fsmall',
  'Gsmall',
  'Hsmall',
  'Ismall',
  'Jsmall',
  'Ksmall',
  'Lsmall',
  'Msmall',
  'Nsmall',
  'Osmall',
  'Psmall',
  'Qsmall',
  'Rsmall',
  'Ssmall',
  'Tsmall',
  'Usmall',
  'Vsmall',
  'Wsmall',
  'Xsmall',
  'Ysmall',
  'Zsmall',
  'colonmonetary',
  'onefitted',
  'rupiah',
  'Tildesmall',
  'exclamdownsmall',
  'centoldstyle',
  'Lslashsmall',
  'Scaronsmall',
  'Zcaronsmall',
  'Dieresissmall',
  'Brevesmall',
  'Caronsmall',
  'Dotaccentsmall',
  'Macronsmall',
  'figuredash',
  'hypheninferior',
  'Ogoneksmall',
  'Ringsmall',
  'Cedillasmall',
  'questiondownsmall',
  'oneeighth',
  'threeeighths',
  'fiveeighths',
  'seveneighths',
  'onethird',
  'twothirds',
  'zerosuperior',
  'foursuperior',
  'fivesuperior',
  'sixsuperior',
  'sevensuperior',
  'eightsuperior',
  'ninesuperior',
  'zeroinferior',
  'oneinferior',
  'twoinferior',
  'threeinferior',
  'fourinferior',
  'fiveinferior',
  'sixinferior',
  'seveninferior',
  'eightinferior',
  'nineinferior',
  'centinferior',
  'dollarinferior',
  'periodinferior',
  'commainferior',
  'Agravesmall',
  'Aacutesmall',
  'Acircumflexsmall',
  'Atildesmall',
  'Adieresissmall',
  'Aringsmall',
  'AEsmall',
  'Ccedillasmall',
  'Egravesmall',
  'Eacutesmall',
  'Ecircumflexsmall',
  'Edieresissmall',
  'Igravesmall',
  'Iacutesmall',
  'Icircumflexsmall',
  'Idieresissmall',
  'Ethsmall',
  'Ntildesmall',
  'Ogravesmall',
  'Oacutesmall',
  'Ocircumflexsmall',
  'Otildesmall',
  'Odieresissmall',
  'OEsmall',
  'Oslashsmall',
  'Ugravesmall',
  'Uacutesmall',
  'Ucircumflexsmall',
  'Udieresissmall',
  'Yacutesmall',
  'Thornsmall',
  'Ydieresissmall',
  '001.000',
  '001.001',
  '001.002',
  '001.003',
  'Black',
  'Bold',
  'Book',
  'Light',
  'Medium',
  'Regular',
  'Roman',
  'Semibold',
];

String? _sidToString(int sid, List<String> customStrings) {
  if (sid >= 0 && sid < _cffStandardStrings.length) {
    return _cffStandardStrings[sid];
  }
  if (sid >= 391) {
    final idx = sid - 391;
    if (idx >= 0 && idx < customStrings.length) return customStrings[idx];
  }
  return null;
}

Map<int, String> _parseCffGlyphNames(ByteData data, int cffOffset) {
  final hdrSize = data.getUint8(cffOffset + 2);
  var ptr = cffOffset + hdrSize;

  final nameIndex = _readCffIndex(data, ptr);
  ptr = nameIndex.endOffset;

  final topDictIndex = _readCffIndex(data, ptr);
  ptr = topDictIndex.endOffset;
  if (topDictIndex.count == 0) return {};

  final stringIndex = _readCffIndex(data, ptr);
  ptr = stringIndex.endOffset;
  final globalSubrIndex = _readCffIndex(data, ptr);
  ptr = globalSubrIndex.endOffset;

  final topDict = _parseCffDict(
    data,
    topDictIndex.starts.first,
    topDictIndex.endsExclusive.first,
  );
  final charsetOperands = topDict[15];
  final charStringsOperands = topDict[17];
  if (charsetOperands == null ||
      charsetOperands.isEmpty ||
      charStringsOperands == null ||
      charStringsOperands.isEmpty) {
    return {};
  }

  final customStrings = <String>[];
  for (var i = 0; i < stringIndex.count; i++) {
    final s = _ascii(
      data,
      stringIndex.starts[i],
      stringIndex.endsExclusive[i] - stringIndex.starts[i],
    );
    customStrings.add(s);
  }

  final charStringsIndex = _readCffIndex(data, cffOffset + charStringsOperands.first.toInt());
  final numGlyphs = charStringsIndex.count;
  if (numGlyphs == 0) return {};

  final glyphToName = <int, String>{0: '.notdef'};
  final charsetOffset = charsetOperands.first.toInt();
  if (charsetOffset <= 2) {
    // Predefined charsets (ISOAdobe/Expert/ExpertSubset) are not expected for icon fonts.
    return glyphToName;
  }

  var p = cffOffset + charsetOffset;
  final format = data.getUint8(p++);
  var glyphIndex = 1;

  void addSidRange(int sid, int count) {
    for (var n = 0; n < count && glyphIndex < numGlyphs; n++) {
      final name = _sidToString(sid + n, customStrings);
      if (name != null) glyphToName[glyphIndex] = name;
      glyphIndex++;
    }
  }

  switch (format) {
    case 0:
      while (glyphIndex < numGlyphs) {
        final sid = _u16(data, p);
        p += 2;
        addSidRange(sid, 1);
      }
    case 1:
      while (glyphIndex < numGlyphs) {
        final first = _u16(data, p);
        p += 2;
        final nLeft = data.getUint8(p++);
        addSidRange(first, nLeft + 1);
      }
    case 2:
      while (glyphIndex < numGlyphs) {
        final first = _u16(data, p);
        p += 2;
        final nLeft = _u16(data, p);
        p += 2;
        addSidRange(first, nLeft + 1);
      }
    default:
      throw StateError('Unsupported CFF charset format: $format');
  }

  return glyphToName;
}

// ---------------------------------------------------------------------------
// Name conversion helpers
// ---------------------------------------------------------------------------

/// Dart reserved words that cannot be used as identifiers.
const _dartReserved = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

String _toSnakeCase(String name) {
  // Replace dots and hyphens with underscores
  var result = name.replaceAll(RegExp('[-.]'), '_');
  // Remove any characters that aren't alphanumeric or underscore
  result = result.replaceAll(RegExp('[^a-zA-Z0-9_]'), '');
  // Collapse multiple underscores
  result = result.replaceAll(RegExp('_+'), '_');
  // Trim leading/trailing underscores
  result = result.replaceAll(RegExp(r'^_+|_+$'), '');
  // Lowercase
  result = result.toLowerCase();
  // Prefix with $ if it starts with a digit
  if (result.isNotEmpty && RegExp('^[0-9]').hasMatch(result)) {
    result = '\$$result';
  }
  // Prefix with $ if it's a Dart reserved word
  if (_dartReserved.contains(result)) {
    result = '\$$result';
  }
  return result;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

class _FamilyMapping {
  final String filename;
  final String dartClass;
  final String fontFamily;
  _FamilyMapping(this.filename, this.dartClass, this.fontFamily);
}

void main(List<String> args) {
  String? fontDir;
  String? output;
  final familyMaps = <_FamilyMapping>[];

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--font-dir':
        fontDir = args[++i];
      case '--output':
        output = args[++i];
      case '--family-map':
        final parts = args[++i].split(':');
        if (parts.length != 3) {
          stderr.writeln('Invalid --family-map format. Expected "filename:DartClass:fontFamily"');
          exit(1);
        }
        familyMaps.add(_FamilyMapping(parts[0], parts[1], parts[2]));
      default:
        stderr.writeln('Unknown argument: ${args[i]}');
        exit(1);
    }
  }

  if (fontDir == null || output == null || familyMaps.isEmpty) {
    stderr.writeln(r'Usage: dart run scripts/generate_icon_font_dart.dart \');
    stderr.writeln('  --font-dir <dir> --output <file> --family-map "file:Class:family" [...]');
    exit(1);
  }

  final buf = StringBuffer();
  buf.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buf.writeln('// Generated by: scripts/generate_icon_font_dart.dart');
  buf.writeln('// ignore_for_file: constant_identifier_names');
  buf.writeln();
  buf.writeln('import "package:flutter/widgets.dart";');

  for (final mapping in familyMaps) {
    final file = File('$fontDir/${mapping.filename}');
    if (!file.existsSync()) {
      stderr.writeln('Font file not found: ${file.path}');
      exit(1);
    }

    final bytes = file.readAsBytesSync();
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final tables = _tableOffsets(data);

    final cmapOff = tables['cmap'];
    if (cmapOff == null) {
      stderr.writeln('Missing cmap table in ${mapping.filename}');
      exit(1);
    }

    final codepointToGlyph = _parseCmap(data, cmapOff);
    Map<int, String> glyphToName = {};
    final postOff = tables['post'];
    if (postOff != null) {
      try {
        glyphToName = _parsePost(data, postOff);
        // ignore: avoid_catching_errors
      } on StateError catch (e) {
        stderr.writeln(
          'Warning: failed to parse post table in ${mapping.filename} ($e). Falling back to CFF names.',
        );
      }
    }
    if (glyphToName.isEmpty) {
      final cffOff = tables['CFF '];
      if (cffOff != null) {
        stdout.writeln('Info: no usable post glyph names in ${mapping.filename}, falling back to CFF charset names.');
        glyphToName = _parseCffGlyphNames(data, cffOff);
      } else {
        stderr.writeln('Warning: no glyph names found in post, and CFF table is missing in ${mapping.filename}.');
      }
    }

    // Build name → codepoint, filtered to PUA range (U+E000–U+F8FF)
    final icons = <String, int>{};
    for (final entry in codepointToGlyph.entries) {
      final codepoint = entry.key;
      if (codepoint < 0xE000 || codepoint > 0xF8FF) continue;
      final name = glyphToName[entry.value];
      if (name == null || name == '.notdef') continue;
      final dartName = _toSnakeCase(name);
      if (dartName.isEmpty) continue;
      // Keep first occurrence if duplicate names map to different codepoints
      icons.putIfAbsent(dartName, () => codepoint);
    }

    final sortedNames = icons.keys.toList()..sort();

    buf.writeln();
    buf.writeln('/// ${mapping.dartClass} icon font.');
    buf.writeln('///');
    buf.writeln('/// ${sortedNames.length} icons available.');
    buf.writeln('class ${mapping.dartClass} {');
    buf.writeln('  ${mapping.dartClass}._();');
    buf.writeln();
    for (final name in sortedNames) {
      final cp = icons[name];
      if (cp == null) continue;
      buf.writeln(
        '  static const IconData $name = IconData(0x${cp.toRadixString(16).toUpperCase()}, fontFamily: "${mapping.fontFamily}");',
      );
    }
    buf.writeln('}');

    stdout.writeln('  ${mapping.dartClass}: ${sortedNames.length} icons from ${mapping.filename}');
  }

  final outFile = File(output);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(buf.toString());
  stdout.writeln('Generated: $output');
}
