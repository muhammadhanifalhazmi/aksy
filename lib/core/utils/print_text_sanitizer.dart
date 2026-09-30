const Map<int, String> _asciiFallbacks = <int, String>{
  0x00A0: ' ',
  0x2010: '-',
  0x2011: '-',
  0x2012: '-',
  0x2013: '-',
  0x2014: '-',
  0x2015: '-',
  0x2018: "'",
  0x2019: "'",
  0x201A: "'",
  0x201B: "'",
  0x201C: '"',
  0x201D: '"',
  0x201E: '"',
  0x2022: '*',
  0x2026: '...',
  0x2212: '-',
  0x00D7: 'x',
  0x00F7: '/',
  0x20AC: 'EUR ',
  0x20B9: 'Rp',
};

const Map<int, String> _transliterations = <int, String>{
  0x00C0: 'A',
  0x00C1: 'A',
  0x00C2: 'A',
  0x00C3: 'A',
  0x00C4: 'A',
  0x00C5: 'A',
  0x00C7: 'C',
  0x00C8: 'E',
  0x00C9: 'E',
  0x00CA: 'E',
  0x00CB: 'E',
  0x00CC: 'I',
  0x00CD: 'I',
  0x00CE: 'I',
  0x00CF: 'I',
  0x00D1: 'N',
  0x00D2: 'O',
  0x00D3: 'O',
  0x00D4: 'O',
  0x00D5: 'O',
  0x00D6: 'O',
  0x00D9: 'U',
  0x00DA: 'U',
  0x00DB: 'U',
  0x00DC: 'U',
  0x00DD: 'Y',
  0x00E0: 'a',
  0x00E1: 'a',
  0x00E2: 'a',
  0x00E3: 'a',
  0x00E4: 'a',
  0x00E5: 'a',
  0x00E7: 'c',
  0x00E8: 'e',
  0x00E9: 'e',
  0x00EA: 'e',
  0x00EB: 'e',
  0x00EC: 'i',
  0x00ED: 'i',
  0x00EE: 'i',
  0x00EF: 'i',
  0x00F1: 'n',
  0x00F2: 'o',
  0x00F3: 'o',
  0x00F4: 'o',
  0x00F5: 'o',
  0x00F6: 'o',
  0x00F9: 'u',
  0x00FA: 'u',
  0x00FB: 'u',
  0x00FC: 'u',
  0x00FD: 'y',
  0x00FF: 'y',
  0x00DF: 'ss',
  0x0152: 'OE',
  0x0153: 'oe',
  0x00D0: 'D',
  0x00F0: 'd',
  0x0110: 'D',
  0x0111: 'd',
};

String _mapRunes(String input, Map<int, String> table, int limit) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune == 0x0A || rune == 0x0D) {
      buffer.writeCharCode(rune);
      continue;
    }
    final mapped = table[rune];
    if (mapped != null) {
      buffer.write(mapped);
      continue;
    }
    if (rune <= limit) {
      buffer.writeCharCode(rune);
      continue;
    }
    buffer.write('?');
  }
  return buffer.toString();
}

/// Teks untuk font PDF bawaan (Helvetica/Courier) yang hanya mendukung Latin-1.
/// Karakter di luar rentang itu diganti agar pembuatan PDF tidak gagal.
String sanitizePdfText(String input) =>
    _mapRunes(input, _asciiFallbacks, 0xFF);

/// Teks untuk printer ESC/POS dengan character table ASCII.
/// Aksen latin ditransliterasi supaya tidak tercetak salah glyph.
String sanitizeThermalText(String input) =>
    _mapRunes(_mapRunes(input, _asciiFallbacks, 0xFF), _transliterations, 0x7E);
