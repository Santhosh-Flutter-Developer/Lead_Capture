import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart'
    show Workbook, Style, HAlignType, VAlignType;
import '/services/services.dart' show ErrorService;
import '/views/views.dart';
import 'download_io.dart'
    if (dart.library.html) 'download_web.dart'
    show saveFileToDownloads;
import 'open_file.dart';

/// Shared "export the rows currently shown in the listing" helper used by the
/// Projects, Tasks and Tickets pages.
///
/// The pages pass in the rows of `controller.filteredItems` - i.e. whatever is
/// left after the search box AND every filter dropdown - so the Excel file
/// always matches what the user is looking at.
class ListingExport {
  ListingExport._();

  /// "2026-11-26 09:49:54" - same format as the web panel's Excel reports.
  static String date(DateTime? d) =>
      d == null ? '' : DateFormat('yyyy-MM-dd HH:mm:ss').format(d);

  static String _stamp() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Builds the .xlsx bytes. A `num` cell is written as a number, everything
  /// else as text.
  static Uint8List buildExcel({
    required String sheetName,
    required List<String> headers,
    required List<List<Object?>> rows,
    List<double>? widths,
  }) {
    final wb = Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = sheetName;

    var styleCount = 0;
    Style style({
      bool bold = false,
      String? fore,
      String? back,
      HAlignType align = HAlignType.left,
    }) {
      final s = wb.styles.add('listing_style_${styleCount++}');
      s.fontName = 'Arial';
      s.fontSize = 10;
      s.bold = bold;
      s.hAlign = align;
      s.vAlign = VAlignType.center;
      if (fore != null) s.fontColor = fore;
      if (back != null) s.backColor = back;
      return s;
    }

    final headStyle = style(bold: true, fore: '#FFFFFF', back: '#2E5EAA');
    final textStyle = style();

    for (var c = 0; c < headers.length; c++) {
      sheet.getRangeByIndex(1, c + 1)
        ..setText(headers[c])
        ..cellStyle = headStyle;
    }

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < headers.length; c++) {
        final v = c < row.length ? row[c] : null;
        final cell = sheet.getRangeByIndex(r + 2, c + 1);
        if (v is num) {
          cell.setNumber(v.toDouble());
        } else {
          final t = (v ?? '').toString().trim();
          if (t.isNotEmpty) cell.setText(t);
        }
        cell.cellStyle = textStyle;
      }
    }

    for (var c = 0; c < headers.length; c++) {
      sheet.getRangeByIndex(1, c + 1).columnWidth =
          (widths != null && c < widths.length) ? widths[c] : 20;
    }
    sheet.getRangeByIndex(1, 1).rowHeight = 22;

    final bytes = wb.saveAsStream();
    wb.dispose();
    return Uint8List.fromList(bytes);
  }

  /// Builds the workbook, saves it as `<filePrefix>_Export_<yyyy-MM-dd>.xlsx`
  /// and tells the user. Never throws - failures are shown in a toast.
  static Future<void> run(
    BuildContext context, {
    required String label, // e.g. "Projects"
    required String filePrefix, // e.g. "Projects"
    required List<String> headers,
    required List<List<Object?>> rows,
    List<double>? widths,
  }) async {
    if (rows.isEmpty) {
      FlushBar.show(context, 'No $label to export', isSuccess: false);
      return;
    }
    try {
      final bytes = buildExcel(
        sheetName: label,
        headers: headers,
        rows: rows,
        widths: widths,
      );
      final path = await saveFileToDownloads(
        bytes,
        fileName: '${filePrefix}_Export_${_stamp()}.xlsx',
      );
      if (!context.mounted) return;
      FlushBar.show(
        context,
        '$label exported successfully (${rows.length} record${rows.length == 1 ? '' : 's'})',
      );
      if (!kIsWeb) openfile(path, context);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (context.mounted) {
        FlushBar.show(context, 'Export failed: $e', isSuccess: false);
      }
    }
  }
}