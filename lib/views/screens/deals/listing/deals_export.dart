import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';

/// Builds the Deals export (.xlsx) from the rows returned by deals.php
/// `export`. Returns the file bytes; saving / opening is done by the caller.
class DealsExport {
  static String _s(dynamic v) => v == null ? '' : v.toString().trim();

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  static String _date(dynamic v) {
    final raw = _s(v);
    if (raw.isEmpty) return '';
    final ms = int.tryParse(raw);
    final dt = ms != null
        ? DateTime.fromMillisecondsSinceEpoch(ms)
        : DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    return dt == null ? raw : DateFormat('dd MMM yyyy hh:mm a').format(dt);
  }

  static Uint8List buildExcel(List<Map<String, dynamic>> rows) {
    final wb = Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = 'Deals';

    // Styles must be registered on the workbook.
    var styleCount = 0;
    Style style({
      bool bold = false,
      double size = 10,
      String? fore,
      String? back,
      HAlignType align = HAlignType.left,
      String? format,
    }) {
      final s = wb.styles.add('deal_style_${styleCount++}');
      s.fontName = 'Arial';
      s.fontSize = size;
      s.bold = bold;
      s.hAlign = align;
      s.vAlign = VAlignType.center;
      if (fore != null) s.fontColor = fore;
      if (back != null) s.backColor = back;
      if (format != null) s.numberFormat = format;
      return s;
    }

    final headStyle = style(bold: true, fore: '#FFFFFF', back: '#2E5EAA');
    final headRight = style(
      bold: true,
      fore: '#FFFFFF',
      back: '#2E5EAA',
      align: HAlignType.right,
    );
    final textStyle = style();
    final boldStyle = style(bold: true);
    final moneyStyle = style(align: HAlignType.right, format: '#,##0.00');

    const headers = [
      'Deal #',
      'Deal Name',
      'Project',
      'Value',
      'Company',
      'Client',
      'Email',
      'Mobile',
      'Status',
      'Notes',
      'Created',
      'Created By',
    ];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(headers[c]);
      cell.cellStyle = c == 3 ? headRight : headStyle;
    }

    for (var i = 0; i < rows.length; i++) {
      final r = i + 2;
      final m = rows[i];
      sheet.getRangeByIndex(r, 1)
        ..setText(_s(m['deal_number']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 2)
        ..setText(_s(m['deal_name']))
        ..cellStyle = boldStyle;
      sheet.getRangeByIndex(r, 3)
        ..setText(_s(m['project_name']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 4)
        ..setNumber(_d(m['deal_value']))
        ..cellStyle = moneyStyle;
      sheet.getRangeByIndex(r, 5)
        ..setText(_s(m['company_name']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 6)
        ..setText(_s(m['client_name']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 7)
        ..setText(_s(m['deal_email']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 8)
        ..setText(_s(m['client_mobile']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 9)
        ..setText(_s(m['status_name']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 10)
        ..setText(_s(m['notes']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 11)
        ..setText(_date(m['created_at']))
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 12)
        ..setText(_s(m['created_by_name']))
        ..cellStyle = textStyle;
    }

    const widths = [9.0, 28.0, 28.0, 14.0, 26.0, 22.0, 28.0, 16.0, 16.0, 36.0, 20.0, 22.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.getRangeByIndex(1, c + 1).columnWidth = widths[c];
    }
    sheet.getRangeByIndex(1, 1).rowHeight = 22;

    final bytes = wb.saveAsStream();
    wb.dispose();
    return Uint8List.fromList(bytes);
  }
}