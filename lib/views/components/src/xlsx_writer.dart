import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Very simple XLSX writer:
/// - One sheet (Sheet1)
/// - All values stored as shared strings (text)
/// Usage:
///   final bytes = await XlsxWriter().create(rows);
///   File('employees.xlsx').writeAsBytes(bytes);
class XlsxWriter {
  /// rows = List of rows, each row = List of cell values.
  /// Example:
  /// [
  ///   ['Emp Code', 'Name', 'Department'],
  ///   ['E001', 'Arul', 'IT'],
  /// ]
  Future<Uint8List> create(List<List<String>> rows) async {
    // 1) Build shared strings
    final Map<String, int> sharedIndex = {};
    final List<String> sharedList = [];

    int getSharedIndex(String value) {
      if (sharedIndex.containsKey(value)) {
        return sharedIndex[value]!;
      } else {
        final idx = sharedList.length;
        sharedList.add(value);
        sharedIndex[value] = idx;
        return idx;
      }
    }

    // Populate shared string table by scanning all cells
    for (final row in rows) {
      for (final cell in row) {
        getSharedIndex(cell);
      }
    }

    // 2) Helper: column index (0-based) -> Excel column letters (A, B, ..., AA, AB, ...)
    String columnName(int index) {
      int n = index + 1; // Excel is 1-based
      String name = '';
      while (n > 0) {
        final rem = (n - 1) % 26;
        name = String.fromCharCode(65 + rem) + name;
        n = (n - 1) ~/ 26;
      }
      return name;
    }

    // 3) Build XML parts

    // [Content_Types].xml
    final contentTypes = '''
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>
''';

    // _rels/.rels
    final relsRels = '''
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
''';

    // xl/_rels/workbook.xml.rels
    final workbookRels = '''
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>
''';

    // xl/workbook.xml
    final workbook = '''
<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
''';

    // xl/sharedStrings.xml
    final sharedCount = sharedList.length;
    final sstBuffer = StringBuffer();
    sstBuffer.write(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'count="$sharedCount" uniqueCount="$sharedCount">\n',
    );

    for (final s in sharedList) {
      // escape XML special chars
      final escaped = const HtmlEscape().convert(s);
      sstBuffer.write('<si><t>$escaped</t></si>\n');
    }

    sstBuffer.write('</sst>');
    final sharedStringsXml = sstBuffer.toString();

    // xl/worksheets/sheet1.xml
    final sheetBuffer = StringBuffer();
    sheetBuffer.write(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"\n'
      '           xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n'
      '  <sheetData>\n',
    );

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      final excelRowIndex = r + 1; // Excel rows start at 1
      sheetBuffer.write('<row r="$excelRowIndex">');
      for (int c = 0; c < row.length; c++) {
        final value = row[c];
        final sstIndex = getSharedIndex(value);
        final colName = columnName(c);
        final ref = '$colName$excelRowIndex';
        sheetBuffer.write('<c r="$ref" t="s"><v>$sstIndex</v></c>');
      }
      sheetBuffer.write('</row>\n');
    }

    sheetBuffer.write(
      '  </sheetData>\n'
      '</worksheet>',
    );
    final sheet1Xml = sheetBuffer.toString();

    // 4) Build ZIP archive
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          '[Content_Types].xml',
          utf8.encode(contentTypes).length,
          utf8.encode(contentTypes),
        ),
      )
      ..addFile(
        ArchiveFile(
          '_rels/.rels',
          utf8.encode(relsRels).length,
          utf8.encode(relsRels),
        ),
      )
      ..addFile(
        ArchiveFile(
          'xl/workbook.xml',
          utf8.encode(workbook).length,
          utf8.encode(workbook),
        ),
      )
      ..addFile(
        ArchiveFile(
          'xl/_rels/workbook.xml.rels',
          utf8.encode(workbookRels).length,
          utf8.encode(workbookRels),
        ),
      )
      ..addFile(
        ArchiveFile(
          'xl/sharedStrings.xml',
          utf8.encode(sharedStringsXml).length,
          utf8.encode(sharedStringsXml),
        ),
      )
      ..addFile(
        ArchiveFile(
          'xl/worksheets/sheet1.xml',
          utf8.encode(sheet1Xml).length,
          utf8.encode(sheet1Xml),
        ),
      );

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }

  /// Helper: directly write to file path
  Future<void> saveToFile(String path, List<List<String>> rows) async {
    final bytes = await create(rows);
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
  }
}
