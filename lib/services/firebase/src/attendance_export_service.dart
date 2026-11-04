import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:leadcapture/models/src/attendance_model.dart';
import 'package:leadcapture/models/src/employee_model.dart';
import 'package:leadcapture/theme/theme.dart';

class AttendanceExportService {
  static String _fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);
  static String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  static String _totalHrs(int totalMins) {
    if (totalMins <= 0) return '-';
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  static Future<void> exportPDF({
    required BuildContext context,
    required List<AttendanceModel> attendanceList,
    required Map<String, EmployeeModel> employeeMap,
    required DateTime fromDate,
    required DateTime toDate,
    required String companyName,
  }) async {
    final pdf = pw.Document();

    const headerBg = PdfColor(0.18, 0.37, 0.67);
    const rowAltBg = PdfColor(0.97, 0.98, 0.99);
    const successClr = PdfColor(0.09, 0.64, 0.37);
    const errorClr = PdfColor(0.86, 0.15, 0.15);
    const mutedClr = PdfColor(0.58, 0.64, 0.72);
    const txtPrimary = PdfColor(0.06, 0.09, 0.16);
    const txtSec = PdfColor(0.28, 0.34, 0.41);
    const greenBadge = PdfColor(0.86, 0.99, 0.90);
    const greyBadge = PdfColor(0.93, 0.93, 0.93);

    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final totalMinsAll = attendanceList.fold<int>(
      0,
      (s, a) => s + (a.workingHourMinutes),
    );
    final avgMins = attendanceList.isNotEmpty
        ? totalMinsAll ~/ attendanceList.length
        : 0;

    final dateRange =
        '${DateFormat('dd MMM yyyy').format(fromDate)} to ${DateFormat('dd MMM yyyy').format(toDate)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 26),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: const pw.BoxDecoration(
                color: headerBg,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ATTENDANCE REPORT',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    dateRange,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _statCard(
                  'Records',
                  '${attendanceList.length}',
                  fontBold,
                  font,
                ),
                pw.SizedBox(width: 8),
                _statCard(
                  'Total Hours',
                  _totalHrs(totalMinsAll),
                  fontBold,
                  font,
                ),
                pw.SizedBox(width: 8),
                _statCard('Avg / Day', _totalHrs(avgMins), fontBold, font),
              ],
            ),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 7.5,
                  color: PdfColors.grey500,
                ),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 7.5,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: const pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 3, child: _th('Employee', fontBold)),
                pw.Expanded(flex: 2, child: _th('Date', fontBold)),
                pw.Expanded(flex: 3, child: _th('Status', fontBold)),
                pw.Expanded(
                  flex: 2,
                  child: _th('Work Hours', fontBold, center: true),
                ),
              ],
            ),
          ),
          ...attendanceList.asMap().entries.map((entry) {
            final idx = entry.key;
            final attendance = entry.value;
            final emp = employeeMap[attendance.employeeId];
            final bg = idx.isEven ? PdfColors.white : rowAltBg;

            return pw.Container(
              decoration: pw.BoxDecoration(
                color: bg,
                border: const pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200),
                  left: pw.BorderSide(color: PdfColors.grey200),
                  right: pw.BorderSide(color: PdfColors.grey200),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          emp?.name ?? 'Unknown',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            color: txtPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      attendance.punchList.isNotEmpty
                          ? _fmtDate(
                              DateTime.parse(
                                attendance.punchList.first.punchDate,
                              ),
                            )
                          : '-',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 9,
                        color: txtSec,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      attendance.status?.name ?? '-',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: txtSec,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Center(
                      child: pw.Text(
                        _totalHrs(attendance.workingHourMinutes),
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 9,
                          color: txtPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    final filename =
        'Attendance_${DateFormat('ddMMyyyy').format(fromDate)}_${DateFormat('ddMMyyyy').format(toDate)}.pdf';
    final pdfBytes = await pdf.save();

    await _saveAndOpen(
      context: context,
      bytes: Uint8List.fromList(pdfBytes),
      filename: filename,
      mimeType: 'application/pdf',
    );
  }

  static Future<void> exportExcel({
    required BuildContext context,
    required List<AttendanceModel> attendanceList,
    required Map<String, EmployeeModel> employeeMap,
    required DateTime fromDate,
    required DateTime toDate,
    required String companyName,
  }) async {
    final workbook = Workbook();
    final sheet = workbook.worksheets[0];

    final dateRange =
        '${DateFormat('dd MMM yyyy').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}';
    final totalMinsAll = attendanceList.fold<int>(
      0,
      (s, a) => s + a.workingHourMinutes,
    );
    final avgMins = attendanceList.isNotEmpty
        ? totalMinsAll ~/ attendanceList.length
        : 0;

    // Header row
    final headerStyle = Style();
    headerStyle.bold = true;
    headerStyle.fontName = 'Arial';
    headerStyle.fontSize = 13;
    headerStyle.hAlign = HAlignType.left;
    headerStyle.backColor = '#2E5EAA';
    headerStyle.fontColor = '#FFFFFF';
    final range = sheet.getRangeByName('A1:F1');
    range.merge();
    range.setText('ATTENDANCE REPORT  |  $dateRange');
    range.cellStyle = headerStyle;

    // Summary row
    final summaryStyle = Style();
    summaryStyle.italic = true;
    summaryStyle.fontName = 'Arial';
    summaryStyle.fontSize = 9;
    summaryStyle.hAlign = HAlignType.left;
    summaryStyle.fontColor = '#475569';
    final summaryRange = sheet.getRangeByName('A2:F2');
    summaryRange.merge();
    summaryRange.setText(
      'Records: ${attendanceList.length}     '
      'Total Hours: ${_totalHrs(totalMinsAll)}     '
      'Avg/Day: ${_totalHrs(avgMins)}     '
      'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
    );
    summaryRange.cellStyle = summaryStyle;

    // Column headers
    const headers = [
      'Employee Name',
      'Date',
      'Status',
      'Work Hours',
      'Less Hours',
      'OT Hours',
    ];
    final headerCellStyle = Style();
    headerCellStyle.bold = true;
    headerCellStyle.fontName = 'Arial';
    headerCellStyle.fontSize = 10;
    headerCellStyle.hAlign = HAlignType.left;
    headerCellStyle.backColor = '#2E5EAA';
    headerCellStyle.fontColor = '#FFFFFF';
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.getRangeByIndex(4, c + 1);
      cell.setText(headers[c]);
      cell.cellStyle = headerCellStyle;
    }

    // Data rows
    for (var i = 0; i < attendanceList.length; i++) {
      final attendance = attendanceList[i];
      final emp = employeeMap[attendance.employeeId];
      final rowIndex = 5 + i;
      final rowBg = i.isEven ? '#FFFFFF' : '#F8FAFC';

      final rowStyle = Style();
      rowStyle.fontName = 'Arial';
      rowStyle.fontSize = 10;
      rowStyle.hAlign = HAlignType.left;
      rowStyle.backColor = rowBg;
      rowStyle.fontColor = '#0F172A';

      final nameStyle = Style();
      nameStyle.bold = true;
      nameStyle.fontName = 'Arial';
      nameStyle.fontSize = 10;
      nameStyle.hAlign = HAlignType.left;
      nameStyle.backColor = rowBg;
      nameStyle.fontColor = '#0F172A';

      sheet.getRangeByIndex(rowIndex, 1).setText(emp?.name ?? 'Unknown');
      sheet.getRangeByIndex(rowIndex, 1).cellStyle = nameStyle;

      sheet
          .getRangeByIndex(rowIndex, 2)
          .setText(
            attendance.punchList.isNotEmpty
                ? _fmtDate(DateTime.parse(attendance.punchList.first.punchDate))
                : '-',
          );
      sheet.getRangeByIndex(rowIndex, 2).cellStyle = rowStyle;

      sheet
          .getRangeByIndex(rowIndex, 3)
          .setText(attendance.status?.name ?? '-');
      sheet.getRangeByIndex(rowIndex, 3).cellStyle = rowStyle;

      sheet
          .getRangeByIndex(rowIndex, 4)
          .setText(
            attendance.punchList.isNotEmpty
                ? attendance.punchList.first.totalHours
                : '-',
          );
      sheet.getRangeByIndex(rowIndex, 4).cellStyle = rowStyle;

      sheet
          .getRangeByIndex(rowIndex, 5)
          .setText(
            attendance.punchList.isNotEmpty
                ? attendance.punchList.first.lessHours
                : '-',
          );
      sheet.getRangeByIndex(rowIndex, 5).cellStyle = rowStyle;

      sheet
          .getRangeByIndex(rowIndex, 6)
          .setText(
            attendance.punchList.isNotEmpty
                ? attendance.punchList.first.otHours
                : '-',
          );
      sheet.getRangeByIndex(rowIndex, 6).cellStyle = rowStyle;
    }

    // Set column widths
    sheet.getRangeByName('A1').columnWidth = 26;
    sheet.getRangeByName('B1').columnWidth = 14;
    sheet.getRangeByName('C1').columnWidth = 14;
    sheet.getRangeByName('D1').columnWidth = 14;
    sheet.getRangeByName('E1').columnWidth = 14;
    sheet.getRangeByName('F1').columnWidth = 14;

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final filename =
        'Attendance_${DateFormat("ddMMyyyy").format(fromDate)}_${DateFormat("ddMMyyyy").format(toDate)}.xlsx';

    await _saveAndOpen(
      context: context,
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static pw.Widget _statCard(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 11,
              color: const PdfColor(0.06, 0.09, 0.16),
            ),
          ),
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 7.5,
              color: const PdfColor(0.58, 0.64, 0.72),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _th(String label, pw.Font font, {bool center = false}) {
    return pw.Text(
      label,
      style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white),
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
    );
  }

  static Future<void> _saveAndOpen({
    required BuildContext context,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      _webDownload(bytes: bytes, filename: filename, mimeType: mimeType);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading $filename...'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await _saveToFileAndOpen(bytes, filename);
    }
  }

  static void _webDownload({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    // Web download implementation
    // This would use dart:html or similar for web
    debugPrint('Web download: $filename (${bytes.length} bytes)');
  }

  static Future<void> _saveToFileAndOpen(
    Uint8List bytes,
    String filename,
  ) async {
    // Mobile/Desktop save implementation
    // This would use path_provider and open_file packages
    debugPrint('Save to file: $filename (${bytes.length} bytes)');
  }
}
