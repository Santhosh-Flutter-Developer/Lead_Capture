import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '/models/models.dart';

/// Builds the Payment Report as a PDF or an Excel (.xlsx) file. Both return
/// the file bytes; saving / opening is left to the caller so it works the
/// same on mobile, desktop and web.
class PaymentReportExportService {
  static final NumberFormat _amount = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 2,
  );

  static String _money(double v) => _amount.format(v).trim();

  /// Text describing the active filters, printed at the top of the export.
  static String filterSummary({
    required String client,
    required String period,
    required String status,
  }) => 'Client: $client   |   Period: $period   |   Status: $status';

  // ─────────────────────────────── PDF ───────────────────────────────

  static Future<Uint8List> buildPdf({
    required List<PaymentReportRow> rows,
    required PaymentReportSummary summary,
    required String filters,
  }) async {
    const brand = PdfColor.fromInt(0xFF2E5EAA);
    const altRow = PdfColor.fromInt(0xFFF5F8FC);
    const green = PdfColor.fromInt(0xFF1B8A4B);
    const greenBg = PdfColor.fromInt(0xFFE0F5E9);
    const amber = PdfColor.fromInt(0xFFB26A00);
    const amberBg = PdfColor.fromInt(0xFFFFF1D6);
    const ink = PdfColor.fromInt(0xFF1B2024);
    const muted = PdfColor.fromInt(0xFF6B7785);

    final font = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final generated = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pw.Widget cell(
      String text, {
      bool header = false,
      pw.TextAlign align = pw.TextAlign.left,
      pw.Font? f,
      PdfColor? color,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: f ?? (header ? bold : font),
          fontSize: header ? 9 : 8.5,
          color: header ? PdfColors.white : (color ?? ink),
        ),
      ),
    );

    pw.Widget statusBadge(PaymentReportStatus s) {
      final done = s == PaymentReportStatus.completed;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            color: done ? greenBg : amberBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Text(
            s.label,
            style: pw.TextStyle(
              font: bold,
              fontSize: 8,
              color: done ? green : amber,
            ),
          ),
        ),
      );
    }

    pw.Widget summaryBox(String label, String value, {PdfColor? color}) =>
        pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(font: font, fontSize: 8, color: muted),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 13,
                    color: color ?? ink,
                  ),
                ),
              ],
            ),
          ),
        );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                color: brand,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Payment Report',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 17,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Generated $generated',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8.5,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              filters,
              style: pw.TextStyle(font: font, fontSize: 8.5, color: muted),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 8, color: muted),
          ),
        ),
        build: (_) => [
          pw.Row(
            children: [
              summaryBox('Clients', '${summary.clients}'),
              summaryBox('Total Deal Value', 'Rs. ${_money(summary.dealValue)}'),
              summaryBox(
                'Received',
                'Rs. ${_money(summary.receivedValue)}',
                color: green,
              ),
              summaryBox(
                'Balance Due',
                'Rs. ${_money(summary.balance)}',
                color: summary.balance > 0.01 ? amber : green,
              ),
              summaryBox(
                'Pending / Completed',
                '${summary.pendingClients} / ${summary.completedClients}',
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(2.4),
              2: pw.FlexColumnWidth(2.6),
              3: pw.FlexColumnWidth(2.6),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(1.5),
              6: pw.FlexColumnWidth(1.5),
              7: pw.FlexColumnWidth(1.2),
            },
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey200),
              bottom: pw.BorderSide(color: PdfColors.grey300),
            ),
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: brand),
                children: [
                  cell('#', header: true),
                  cell('Client', header: true),
                  cell('Client Deals', header: true),
                  cell('Project Updations', header: true),
                  cell('Deal Value (Rs.)', header: true, align: pw.TextAlign.right),
                  cell('Received (Rs.)', header: true, align: pw.TextAlign.right),
                  cell('Balance (Rs.)', header: true, align: pw.TextAlign.right),
                  cell('Status', header: true),
                ],
              ),
              for (var i = 0; i < rows.length; i++)
                pw.TableRow(
                  decoration: i.isOdd
                      ? const pw.BoxDecoration(color: altRow)
                      : null,
                  children: [
                    cell('${i + 1}', color: muted),
                    cell(rows[i].clientName, f: bold),
                    cell(
                      rows[i].deals.isEmpty
                          ? '-'
                          : '${rows[i].deals.length}: ${rows[i].dealNames}',
                    ),
                    cell(
                      rows[i].updations.isEmpty
                          ? '-'
                          : '${rows[i].updations.length}: ${rows[i].updationNames}',
                    ),
                    cell(
                      _money(rows[i].dealValue),
                      align: pw.TextAlign.right,
                    ),
                    cell(
                      _money(rows[i].receivedValue),
                      align: pw.TextAlign.right,
                      color: green,
                    ),
                    cell(
                      _money(rows[i].balance),
                      align: pw.TextAlign.right,
                      color: rows[i].balance > 0.01 ? amber : muted,
                    ),
                    statusBadge(rows[i].status),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  cell(''),
                  cell('Total', f: bold),
                  cell(''),
                  cell(''),
                  cell(
                    _money(summary.dealValue),
                    align: pw.TextAlign.right,
                    f: bold,
                  ),
                  cell(
                    _money(summary.receivedValue),
                    align: pw.TextAlign.right,
                    f: bold,
                    color: green,
                  ),
                  cell(
                    _money(summary.balance),
                    align: pw.TextAlign.right,
                    f: bold,
                  ),
                  cell(''),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  // ────────────────────────────── EXCEL ──────────────────────────────

  static Uint8List buildExcel({
    required List<PaymentReportRow> rows,
    required PaymentReportSummary summary,
    required String filters,
  }) {
    final wb = Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = 'Payment Report';

    // Styles must be registered on the workbook (a bare `Style()` is not a
    // valid cell style and throws a TypeError).
    var styleCount = 0;
    Style style({
      bool bold = false,
      double size = 10,
      String? fore,
      String? back,
      HAlignType align = HAlignType.left,
      String? format,
    }) {
      final s = wb.styles.add('pr_style_${styleCount++}');
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

    final statusStyles = <bool, Style>{};
    Style statusStyle(bool done) => statusStyles.putIfAbsent(
      done,
      () => style(
        bold: true,
        fore: done ? '#1B8A4B' : '#B26A00',
        back: done ? '#E0F5E9' : '#FFF1D6',
        align: HAlignType.center,
      ),
    );

    const money = '#,##0.00';
    final titleStyle = style(bold: true, size: 15, fore: '#FFFFFF', back: '#2E5EAA');
    final noteStyle = style(size: 9, fore: '#475569');
    final headStyle = style(bold: true, fore: '#FFFFFF', back: '#2E5EAA');
    final headRight = style(bold: true, fore: '#FFFFFF', back: '#2E5EAA', align: HAlignType.right);
    final textStyle = style();
    final boldStyle = style(bold: true);
    final moneyStyle = style(align: HAlignType.right, format: money);
    final greenMoney = style(align: HAlignType.right, format: money, fore: '#1B8A4B');
    final totalText = style(bold: true, back: '#EEF2F7');
    final totalMoney = style(bold: true, back: '#EEF2F7', align: HAlignType.right, format: money);

    // Title + filters.
    final title = sheet.getRangeByName('A1:H1');
    title.merge();
    title.setText('PAYMENT REPORT');
    title.cellStyle = titleStyle;
    sheet.getRangeByName('A1').rowHeight = 26;

    final note = sheet.getRangeByName('A2:H2');
    note.merge();
    note.setText(
      '$filters   |   Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
    );
    note.cellStyle = noteStyle;

    // Summary line.
    final sum = sheet.getRangeByName('A3:H3');
    sum.merge();
    sum.setText(
      'Clients: ${summary.clients}   Pending: ${summary.pendingClients}   '
      'Completed: ${summary.completedClients}   '
      'Deal Value: ${_money(summary.dealValue)}   '
      'Received: ${_money(summary.receivedValue)}   '
      'Balance: ${_money(summary.balance)}',
    );
    sum.cellStyle = style(bold: true, size: 9, fore: '#1B2024');

    // Header.
    const headers = [
      'S.No',
      'Client',
      'Client Deals',
      'Client Project Updations',
      'Deal Value',
      'Received Value',
      'Balance',
      'Status',
    ];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.getRangeByIndex(5, c + 1);
      cell.setText(headers[c]);
      cell.cellStyle = (c >= 4 && c <= 6) ? headRight : headStyle;
    }

    // Data.
    var r = 6;
    for (var i = 0; i < rows.length; i++, r++) {
      final row = rows[i];
      final done = row.isCompleted;
      sheet.getRangeByIndex(r, 1)
        ..setNumber(i + 1.0)
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 2)
        ..setText(row.clientName)
        ..cellStyle = boldStyle;
      sheet.getRangeByIndex(r, 3)
        ..setText(row.deals.isEmpty ? '-' : row.dealNames)
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 4)
        ..setText(row.updations.isEmpty ? '-' : row.updationNames)
        ..cellStyle = textStyle;
      sheet.getRangeByIndex(r, 5)
        ..setNumber(row.dealValue)
        ..cellStyle = moneyStyle;
      sheet.getRangeByIndex(r, 6)
        ..setNumber(row.receivedValue)
        ..cellStyle = greenMoney;
      sheet.getRangeByIndex(r, 7)
        ..setNumber(row.balance)
        ..cellStyle = moneyStyle;
      sheet.getRangeByIndex(r, 8)
        ..setText(row.status.label)
        ..cellStyle = statusStyle(done);
    }

    // Totals.
    for (var c = 1; c <= 8; c++) {
      sheet.getRangeByIndex(r, c).cellStyle = totalText;
    }
    sheet.getRangeByIndex(r, 2).setText('Total');
    sheet.getRangeByIndex(r, 5)
      ..setNumber(summary.dealValue)
      ..cellStyle = totalMoney;
    sheet.getRangeByIndex(r, 6)
      ..setNumber(summary.receivedValue)
      ..cellStyle = totalMoney;
    sheet.getRangeByIndex(r, 7)
      ..setNumber(summary.balance)
      ..cellStyle = totalMoney;

    const widths = [7.0, 30.0, 40.0, 40.0, 16.0, 16.0, 16.0, 13.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.getRangeByIndex(1, c + 1).columnWidth = widths[c];
    }
    sheet.getRangeByName('A5:H5').rowHeight = 22;

    // Sheet 2: every deal / updation on its own line.
    final detail = wb.worksheets.addWithName('Details');
    const dHeaders = [
      'Client',
      'Type',
      'Item',
      'Project',
      'Value',
      'Received',
      'Balance',
      'Status',
    ];
    for (var c = 0; c < dHeaders.length; c++) {
      final cell = detail.getRangeByIndex(1, c + 1);
      cell.setText(dHeaders[c]);
      cell.cellStyle = (c >= 4 && c <= 6) ? headRight : headStyle;
    }
    var d = 2;
    void line(
      String client,
      String type,
      String item,
      String project,
      double value,
      double received,
      PaymentReportStatus status,
    ) {
      final done = status == PaymentReportStatus.completed;
      detail.getRangeByIndex(d, 1)
        ..setText(client)
        ..cellStyle = boldStyle;
      detail.getRangeByIndex(d, 2)
        ..setText(type)
        ..cellStyle = textStyle;
      detail.getRangeByIndex(d, 3)
        ..setText(item)
        ..cellStyle = textStyle;
      detail.getRangeByIndex(d, 4)
        ..setText(project)
        ..cellStyle = textStyle;
      detail.getRangeByIndex(d, 5)
        ..setNumber(value)
        ..cellStyle = moneyStyle;
      detail.getRangeByIndex(d, 6)
        ..setNumber(received)
        ..cellStyle = greenMoney;
      detail.getRangeByIndex(d, 7)
        ..setNumber(value - received)
        ..cellStyle = moneyStyle;
      detail.getRangeByIndex(d, 8)
        ..setText(status.label)
        ..cellStyle = statusStyle(done);
      d++;
    }

    for (final row in rows) {
      for (final deal in row.deals) {
        line(
          row.clientName,
          'Deal',
          deal.dealNumber == null ? deal.name : '#${deal.dealNumber} ${deal.name}',
          deal.name,
          deal.value,
          deal.received,
          deal.status,
        );
      }
      for (final u in row.updations) {
        line(
          row.clientName,
          'Project Updation',
          u.title.isEmpty ? u.code : '${u.code} ${u.title}',
          u.projectName,
          u.value,
          u.received,
          u.status,
        );
      }
    }
    const dWidths = [30.0, 18.0, 38.0, 28.0, 16.0, 16.0, 16.0, 13.0];
    for (var c = 0; c < dWidths.length; c++) {
      detail.getRangeByIndex(1, c + 1).columnWidth = dWidths[c];
    }

    final bytes = wb.saveAsStream();
    wb.dispose();
    return Uint8List.fromList(bytes);
  }
}