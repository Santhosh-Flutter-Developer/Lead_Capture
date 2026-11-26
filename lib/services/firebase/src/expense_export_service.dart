import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '/models/models.dart';

/// Builds the Expense listing export, the Expense Report (Excel / PDF) and the
/// printable Expense Voucher. All return file bytes; saving / opening is left
/// to the caller so it works the same on mobile, desktop and web.
class ExpenseExportService {
  static final NumberFormat _amount =
      NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 2);
  static String _money(double v) => _amount.format(v).trim();
  static String _date(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  static String _dash(String s) => s.trim().isEmpty ? '-' : s.trim();

  static const _brand = PdfColor.fromInt(0xFF1D4ED8);
  static const _ink = PdfColor.fromInt(0xFF1B2024);
  static const _muted = PdfColor.fromInt(0xFF6B7785);
  static const _alt = PdfColor.fromInt(0xFFF5F8FC);

  // ───────────────────────── Excel helpers ─────────────────────────

  static Style Function({
    bool bold,
    double size,
    String? fore,
    String? back,
    HAlignType align,
    String? format,
  }) _styler(Workbook wb) {
    var n = 0;
    return ({
      bool bold = false,
      double size = 10,
      String? fore,
      String? back,
      HAlignType align = HAlignType.left,
      String? format,
    }) {
      final s = wb.styles.add('exp_style_${n++}');
      s.fontName = 'Arial';
      s.fontSize = size;
      s.bold = bold;
      s.hAlign = align;
      s.vAlign = VAlignType.center;
      if (fore != null) s.fontColor = fore;
      if (back != null) s.backColor = back;
      if (format != null) s.numberFormat = format;
      return s;
    };
  }

  // ───────────────────── Listing export (Excel) ─────────────────────

  static Uint8List buildListExcel(List<ExpenseModel> items) {
    final wb = Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = 'Expenses';
    final style = _styler(wb);
    final head = style(bold: true, fore: '#FFFFFF', back: '#1D4ED8');
    final headRight =
        style(bold: true, fore: '#FFFFFF', back: '#1D4ED8', align: HAlignType.right);
    final text = style();
    final money = style(align: HAlignType.right, format: '#,##0.00');
    final cancelled = style(fore: '#DC3545', bold: true);

    const headers = [
      'Expense No',
      'Expense Date',
      'Our Company',
      'Category',
      'Amount',
      'Payment Mode',
      'UPI Number',
      'Description',
      'Status',
      'Cancellation Remarks',
      'Created By',
      'Created At',
    ];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(headers[c]);
      cell.cellStyle = c == 4 ? headRight : head;
    }
    for (var i = 0; i < items.length; i++) {
      final e = items[i];
      final r = i + 2;
      void t(int c, String v, [Style? s]) {
        sheet.getRangeByIndex(r, c)
          ..setText(v)
          ..cellStyle = s ?? text;
      }

      t(1, e.expenseNumber);
      t(2, DateFormat('yyyy-MM-dd').format(e.expenseDate));
      t(3, e.masterCompanyName);
      t(4, e.categoryName);
      sheet.getRangeByIndex(r, 5)
        ..setNumber(e.amount)
        ..cellStyle = money;
      t(6, e.paymentMode);
      t(7, e.upiNumber);
      t(8, e.description);
      t(9, e.isCancelled ? 'Cancelled' : 'Active', e.isCancelled ? cancelled : text);
      t(10, e.cancellationRemarks);
      t(11, e.createdBy.name);
      t(12, DateFormat('yyyy-MM-dd HH:mm').format(e.createdAt));
    }
    const widths = [14.0, 14.0, 26.0, 20.0, 14.0, 16.0, 18.0, 36.0, 12.0, 30.0, 20.0, 18.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.getRangeByIndex(1, c + 1).columnWidth = widths[c];
    }
    final bytes = wb.saveAsStream();
    wb.dispose();
    return Uint8List.fromList(bytes);
  }

  // ───────────────────────── Report filters ─────────────────────────

  static String filterSummary({
    required String company,
    required String category,
    required String mode,
    required String period,
  }) => 'Company: $company   |   Category: $category   |   Mode: $mode   |   Date: $period';

  // ───────────────────────── Report (Excel) ─────────────────────────

  static Uint8List buildReportExcel({
    required List<ExpenseModel> rows,
    required ExpenseReportSummary summary,
    required String from,
    required String to,
    required String company,
    required String category,
    required String mode,
  }) {
    final wb = Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = 'Expense_Report';
    final style = _styler(wb);
    final title = style(bold: true, size: 15, fore: '#FFFFFF', back: '#1D4ED8');
    final note = style(size: 9, fore: '#475569');
    final noteBold = style(size: 10, bold: true);
    final head = style(bold: true, fore: '#FFFFFF', back: '#1D4ED8');
    final headRight =
        style(bold: true, fore: '#FFFFFF', back: '#1D4ED8', align: HAlignType.right);
    final text = style();
    final bold = style(bold: true);
    final money = style(align: HAlignType.right, format: '#,##0.00');
    final totalText = style(bold: true, back: '#EEF2F7');
    final totalMoney =
        style(bold: true, back: '#EEF2F7', align: HAlignType.right, format: '#,##0.00');

    final t = sheet.getRangeByName('A1:H1');
    t.merge();
    t.setText('EXPENSE REPORT');
    t.cellStyle = title;
    sheet.getRangeByName('A1').rowHeight = 26;

    void kv(int r, String k1, String v1, String k2, String v2) {
      sheet.getRangeByIndex(r, 1)
        ..setText(k1)
        ..cellStyle = noteBold;
      sheet.getRangeByIndex(r, 2)
        ..setText(v1)
        ..cellStyle = note;
      sheet.getRangeByIndex(r, 4)
        ..setText(k2)
        ..cellStyle = noteBold;
      sheet.getRangeByIndex(r, 5)
        ..setText(v2)
        ..cellStyle = note;
    }

    kv(3, 'From Date:', from, 'To Date:', to);
    kv(4, 'Company:', company, 'Category:', category);
    kv(5, 'Payment Mode:', mode, 'Generated:',
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()));

    const headers = [
      'S.No',
      'Expense Date',
      'Expense Number',
      'Company Name',
      'Category Name',
      'Description',
      'Payment Mode',
      'Amount',
    ];
    const hr = 7;
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.getRangeByIndex(hr, c + 1);
      cell.setText(headers[c]);
      cell.cellStyle = c == 7 ? headRight : head;
    }
    var r = hr + 1;
    var total = 0.0;
    for (var i = 0; i < rows.length; i++, r++) {
      final e = rows[i];
      total += e.amount;
      sheet.getRangeByIndex(r, 1)
        ..setNumber(i + 1.0)
        ..cellStyle = text;
      sheet.getRangeByIndex(r, 2)
        ..setText(DateFormat('yyyy-MM-dd').format(e.expenseDate))
        ..cellStyle = text;
      sheet.getRangeByIndex(r, 3)
        ..setText(e.expenseNumber)
        ..cellStyle = bold;
      sheet.getRangeByIndex(r, 4)
        ..setText(e.masterCompanyName)
        ..cellStyle = text;
      sheet.getRangeByIndex(r, 5)
        ..setText(e.categoryName)
        ..cellStyle = text;
      sheet.getRangeByIndex(r, 6)
        ..setText(e.description)
        ..cellStyle = text;
      sheet.getRangeByIndex(r, 7)
        ..setText(e.paymentMode)
        ..cellStyle = text;
      sheet.getRangeByIndex(r, 8)
        ..setNumber(e.amount)
        ..cellStyle = money;
    }
    for (var c = 1; c <= 8; c++) {
      sheet.getRangeByIndex(r, c).cellStyle = totalText;
    }
    sheet.getRangeByIndex(r, 1).setText('Total');
    sheet.getRangeByIndex(r, 8)
      ..setNumber(total)
      ..cellStyle = totalMoney;

    const widths = [7.0, 14.0, 16.0, 28.0, 22.0, 36.0, 16.0, 16.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.getRangeByIndex(1, c + 1).columnWidth = widths[c];
    }
    final bytes = wb.saveAsStream();
    wb.dispose();
    return Uint8List.fromList(bytes);
  }

  // ───────────────────────── Report (PDF) ─────────────────────────

  static Future<Uint8List> buildReportPdf({
    required List<ExpenseModel> rows,
    required ExpenseReportSummary summary,
    required String filters,
  }) async {
    final font = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final generated = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final total = rows.fold<double>(0, (a, e) => a + e.amount);

    pw.Widget cell(String text,
            {bool header = false,
            pw.TextAlign align = pw.TextAlign.left,
            pw.Font? f,
            PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              font: f ?? (header ? bold : font),
              fontSize: header ? 9 : 8.5,
              color: header ? PdfColors.white : (color ?? _ink),
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const pw.BoxDecoration(
                color: _brand,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('EXPENSE REPORT',
                      style: pw.TextStyle(font: bold, fontSize: 17, color: PdfColors.white)),
                  pw.Text('Generated $generated',
                      style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(filters, style: pw.TextStyle(font: font, fontSize: 8.5, color: _muted)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 8, color: _muted)),
        ),
        build: (_) => [
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(26),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(2.4),
              4: pw.FlexColumnWidth(2),
              5: pw.FlexColumnWidth(2.6),
              6: pw.FlexColumnWidth(1.3),
              7: pw.FlexColumnWidth(1.5),
            },
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey200),
              bottom: pw.BorderSide(color: PdfColors.grey300),
            ),
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: _brand),
                children: [
                  cell('S.No', header: true),
                  cell('Expense Date', header: true),
                  cell('Expense Number', header: true),
                  cell('Company Name', header: true),
                  cell('Category Name', header: true),
                  cell('Description', header: true),
                  cell('Payment Mode', header: true),
                  cell('Amount', header: true, align: pw.TextAlign.right),
                ],
              ),
              for (var i = 0; i < rows.length; i++)
                pw.TableRow(
                  decoration: i.isOdd ? const pw.BoxDecoration(color: _alt) : null,
                  children: [
                    cell('${i + 1}', color: _muted),
                    cell(_date(rows[i].expenseDate)),
                    cell(rows[i].expenseNumber, f: bold),
                    cell(rows[i].masterCompanyName),
                    cell(rows[i].categoryName),
                    cell(_dash(rows[i].description)),
                    cell(rows[i].paymentMode),
                    cell('Rs. ${_money(rows[i].amount)}', align: pw.TextAlign.right),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  cell(''),
                  cell(''),
                  cell(''),
                  cell(''),
                  cell(''),
                  cell(''),
                  cell('Total', f: bold, align: pw.TextAlign.right),
                  cell('Rs. ${_money(total)}', f: bold, align: pw.TextAlign.right),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  // ───────────────────────── Voucher (PDF) ─────────────────────────

  static Future<Uint8List> buildVoucherPdf(ExpenseModel e) async {
    final font = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

    pw.Widget row(String k, String v) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 120,
                child: pw.Text(k, style: pw.TextStyle(font: bold, fontSize: 10, color: _muted)),
              ),
              pw.Expanded(child: pw.Text(v, style: pw.TextStyle(font: font, fontSize: 10.5))),
            ],
          ),
        );

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(e.masterCompanyName,
                          style: pw.TextStyle(font: bold, fontSize: 16)),
                      pw.SizedBox(height: 3),
                      pw.Text('Voucher No: ${e.expenseNumber}',
                          style: pw.TextStyle(font: font, fontSize: 9.5, color: _muted)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('EXPENSE VOUCHER',
                          style: pw.TextStyle(font: bold, fontSize: 16, color: _brand)),
                      pw.SizedBox(height: 3),
                      pw.Text(e.expenseNumber,
                          style: pw.TextStyle(font: bold, fontSize: 11)),
                      pw.Text('Date: ${_date(e.expenseDate)}',
                          style: pw.TextStyle(font: font, fontSize: 9.5, color: _muted)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Container(height: 2, color: _brand),
              pw.SizedBox(height: 10),
              row('Expense Category', e.categoryName),
              row('Payment Mode',
                  e.upiNumber.isEmpty ? e.paymentMode : '${e.paymentMode} (${e.upiNumber})'),
              row('Description / Purpose', _dash(e.description)),
              row('Recorded By',
                  '${e.createdBy.name} on ${DateFormat('dd MMM yyyy, hh:mm a').format(e.createdAt)}'),
              if (e.isCancelled)
                row('Status',
                    'CANCELLED - ${_dash(e.cancellationRemarks)}${e.cancelledByName.isEmpty ? '' : ' (by ${e.cancelledByName})'}'),
              pw.SizedBox(height: 14),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: _alt,
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Text('Total Amount:  Rs. ${_money(e.amount)}',
                      style: pw.TextStyle(font: bold, fontSize: 14, color: _brand)),
                ),
              ),
              pw.SizedBox(height: 60),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  for (final s in ['Prepared By', 'Verified / Checked By', 'Authorized / Receiver Sign'])
                    pw.Column(
                      children: [
                        pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                        pw.SizedBox(height: 4),
                        pw.Text(s, style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }
}