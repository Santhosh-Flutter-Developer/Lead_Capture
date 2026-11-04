// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

class CsvReader {
  final String delimiter;
  CsvReader({this.delimiter = ','});

  /// Parse CSV text into list of rows (each row is List)
  List<List<String>> parse(String input) {
    final List<List<String>> rows = [];
    final int n = input.length;
    int i = 0;
    List<String> currentRow = [];
    final sb = StringBuffer();
    bool inQuotes = false;

    String readChar() => i < n ? input[i] : '\x00';

    while (i <= n) {
      final c = readChar();

      if (inQuotes) {
        if (c == '"') {
          // peek next char
          final next = (i + 1 <= n - 1) ? input[i + 1] : '\x00';
          if (next == '"') {
            // escaped quote
            sb.write('"');
            i += 2;
            continue;
          } else {
            // end of quoted field
            inQuotes = false;
            i++;
            continue;
          }
        } else {
          sb.write(c);
          i++;
          continue;
        }
      } else {
        // not in quotes
        if (c == '"') {
          inQuotes = true;
          i++;
          continue;
        }

        if (c == delimiter) {
          currentRow.add(sb.toString());
          sb.clear();
          i++;
          continue;
        }

        // handle CRLF, LF, CR as row terminators
        if (c == '\r') {
          // peek for \n
          final next = (i + 1 <= n - 1) ? input[i + 1] : '\x00';
          if (next == '\n') i++;
          currentRow.add(sb.toString());
          sb.clear();
          rows.add(List.unmodifiable(currentRow));
          currentRow = [];
          i++;
          continue;
        }

        if (c == '\n' || c == '\x00') {
          currentRow.add(sb.toString());
          sb.clear();
          rows.add(List.unmodifiable(currentRow));
          currentRow = [];
          i++;
          // stop when end marker reached
          continue;
        }

        // normal character
        sb.write(c);
        i++;
      }
    }

    return rows;
  }

  /// Helper to parse from a file
  Future<List<List<String>>> parseFile(
    String path, {
    Encoding encoding = utf8,
  }) async {
    final content = await File(path).readAsString(encoding: encoding);
    return parse(content);
  }
}

// pubspec.yaml dependencies:
//   archive: ^3.3.0
//   xml: ^6.1.0

class XlsxReader {
  // ignore: unintended_html_in_doc_comment
  /// Read XLSX bytes and return list of rows (List<List<String>>)
  Future<List<List<String>>> readFromBytes(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    // Helper to read a file content as string (or null)
    String? readEntryContent(String path) {
      final normalizedPath = path.replaceAll('\\', '/');
      for (final file in archive) {
        final entryName = file.name.replaceAll('\\', '/');
        if (entryName == normalizedPath) {
          final data = file.content as List<int>;
          return String.fromCharCodes(data);
        }
      }
      return null;
    }

    // 1) find workbook.xml to map sheet ids -> path
    final workbookXml = readEntryContent('xl/workbook.xml');
    if (workbookXml == null) {
      throw Exception('xl/workbook.xml not found inside xlsx');
    }
    final workbookDoc = XmlDocument.parse(workbookXml);

    final sheetElements = workbookDoc.findAllElements('sheet').toList();
    final sheetNameToPath = <String, String>{};
    if (sheetElements.isNotEmpty) {
      final relsXml = readEntryContent('xl/_rels/workbook.xml.rels');
      final relsDoc = relsXml != null ? XmlDocument.parse(relsXml) : null;

      for (final sheet in sheetElements) {
        final name = sheet.getAttribute('name') ?? '';
        final rid =
            sheet.getAttribute('r:id') ?? sheet.getAttribute('id') ?? '';
        String? target;
        if (relsDoc != null && rid.isNotEmpty) {
          final rel = relsDoc
              .findAllElements('Relationship')
              .firstWhere(
                (r) => r.getAttribute('Id') == rid,
                orElse: () => XmlElement(XmlName('')),
              );
          if (rel.name.local.isNotEmpty) {
            target = rel.getAttribute('Target');
          }
        }
        if (target == null || target.isEmpty) {
          final sheetId = sheet.getAttribute('sheetId') ?? '';
          if (sheetId.isNotEmpty) {
            target = 'xl/worksheets/sheet$sheetId.xml';
          }
        } else {
          target = target.replaceFirst(RegExp(r'^/'), '');
          if (!target.startsWith('xl/')) {
            target = 'xl/$target';
          }
        }

        if (target != null && target.isNotEmpty) {
          sheetNameToPath[name] = target;
        }
      }
    }

    if (sheetNameToPath.isEmpty) {
      throw Exception('No sheets found in workbook');
    }
    final firstSheetPath = sheetNameToPath.values.first;

    // 2) parse shared strings
    final sharedStringsXml = readEntryContent('xl/sharedStrings.xml');
    final sharedStrings = <String>[];
    if (sharedStringsXml != null) {
      final ssDoc = XmlDocument.parse(sharedStringsXml);
      final siList = ssDoc.findAllElements('si');
      for (final si in siList) {
        final ts = si.findAllElements('t');
        final buffer = StringBuffer();
        for (final t in ts) {
          buffer.write(t.text);
        }
        sharedStrings.add(buffer.toString());
      }
    }

    // 2.5) parse styles for date detection
    final stylesXml = readEntryContent('xl/styles.xml');
    final List<int> styleNumFmtIds = [];
    final Map<int, String> customNumFmtCodes = {};

    if (stylesXml != null) {
      final stylesDoc = XmlDocument.parse(stylesXml);

      // custom numFmt definitions
      for (final numFmt in stylesDoc.findAllElements('numFmt')) {
        final idStr = numFmt.getAttribute('numFmtId');
        final fmt = numFmt.getAttribute('formatCode') ?? '';
        if (idStr != null) {
          final id = int.tryParse(idStr);
          if (id != null) {
            customNumFmtCodes[id] = fmt;
          }
        }
      }

      // cellXfs holds style index -> numFmtId mapping
      final cellXfs = stylesDoc
          .findAllElements('cellXfs')
          .firstWhere((_) => true, orElse: () => XmlElement(XmlName('')));
      if (cellXfs.name.local.isNotEmpty) {
        for (final xf in cellXfs.findAllElements('xf')) {
          final numFmtIdStr = xf.getAttribute('numFmtId') ?? '0';
          final numFmtId = int.tryParse(numFmtIdStr) ?? 0;
          styleNumFmtIds.add(numFmtId);
        }
      }
    }

    bool isDateNumFmt(int numFmtId) {
      // Built-in Excel date formats
      const builtInDateIds = {14, 15, 16, 17, 22, 45, 46, 47};
      if (builtInDateIds.contains(numFmtId)) return true;

      final fmt = customNumFmtCodes[numFmtId];
      if (fmt == null) return false;

      final lower = fmt.toLowerCase();
      // very simple heuristic: contains d/m/y and not only "general"
      if (lower.contains('yy') || lower.contains('dd')) return true;
      return false;
    }

    DateTime excelSerialToDate(double serial) {
      final base = DateTime(1899, 12, 30); // typical Excel base date
      final days = serial.floor();
      final fraction = serial - days;
      final date = base.add(Duration(days: days));
      final seconds = (fraction * 86400).round();
      return date.add(Duration(seconds: seconds));
    }

    String formatDate(DateTime dt) {
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$dd-$mm-$yyyy'; // your desired format
    }

    // 3) read sheet xml (first sheet)
    final sheetXml = readEntryContent(firstSheetPath);
    if (sheetXml == null) {
      throw Exception('Worksheet $firstSheetPath not found');
    }
    final sheetDoc = XmlDocument.parse(sheetXml);

    int colLetterToIndex(String ref) {
      final letters = RegExp(r'^[A-Z]+').firstMatch(ref)?.group(0) ?? '';
      int idx = 0;
      for (var i = 0; i < letters.length; i++) {
        idx = idx * 26 + (letters.codeUnitAt(i) - 'A'.codeUnitAt(0) + 1);
      }
      return idx - 1;
    }

    final rowsOut = <List<String>>[];

    for (final rowElem in sheetDoc.findAllElements('row')) {
      final cells = rowElem.findAllElements('c').toList();
      int maxCol = -1;
      for (final c in cells) {
        final ref = c.getAttribute('r') ?? '';
        final colIdx = colLetterToIndex(ref);
        if (colIdx > maxCol) maxCol = colIdx;
      }
      final currentRow = List<String>.filled(maxCol + 1, '');

      for (final c in cells) {
        final ref = c.getAttribute('r') ?? '';
        final colIdx = colLetterToIndex(ref);
        final type = c.getAttribute('t'); // 's', 'b', 'inlineStr', etc.
        final styleIndexStr = c.getAttribute('s');
        int? styleIndex = styleIndexStr != null
            ? int.tryParse(styleIndexStr)
            : null;

        bool treatAsDate = false;
        if (styleIndex != null &&
            styleIndex >= 0 &&
            styleIndex < styleNumFmtIds.length) {
          final numFmtId = styleNumFmtIds[styleIndex];
          treatAsDate = isDateNumFmt(numFmtId);
        }

        String value = '';

        if (type == 's') {
          final vElem = c
              .findElements('v')
              .firstWhere((_) => true, orElse: () => XmlElement(XmlName('')));
          if (vElem.name.local.isNotEmpty) {
            final idx = int.tryParse(vElem.text) ?? -1;
            if (idx >= 0 && idx < sharedStrings.length) {
              value = sharedStrings[idx];
            }
          }
        } else if (type == 'inlineStr' || c.findElements('is').isNotEmpty) {
          final isElem = c
              .findElements('is')
              .firstWhere((_) => true, orElse: () => XmlElement(XmlName('')));
          if (isElem.name.local.isNotEmpty) {
            final t = isElem.findAllElements('t').map((e) => e.text).join();
            value = t;
          } else {
            final tElem = c
                .findAllElements('t')
                .firstWhere((_) => true, orElse: () => XmlElement(XmlName('')));
            if (tElem.name.local.isNotEmpty) value = tElem.text;
          }
        } else if (type == 'b') {
          final v = c.findElements('v').isEmpty
              ? ''
              : c.findElements('v').first.text;
          if (v == '1') {
            value = 'TRUE';
          } else if (v == '0') {
            value = 'FALSE';
          } else {
            value = v;
          }
        } else {
          // numeric / formula / general
          final vElem = c.findElements('v').isEmpty
              ? null
              : c.findElements('v').first;
          if (vElem != null) {
            final raw = vElem.text;
            if (treatAsDate) {
              final numVal = double.tryParse(raw);
              if (numVal != null) {
                final dt = excelSerialToDate(numVal);
                value = formatDate(dt);
              } else {
                value = raw;
              }
            } else {
              value = raw;
            }
          } else {
            final tElems = c.findAllElements('t').toList();
            if (tElems.isNotEmpty) {
              value = tElems.map((t) => t.text).join();
            }
          }
        }

        currentRow[colIdx] = value;
      }

      rowsOut.add(currentRow);
    }

    return rowsOut;
  }

  Future<List<List<String>>> readFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return readFromBytes(bytes);
  }
}
