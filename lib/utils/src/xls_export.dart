class XlsExport {
  // static Future rideReportExport({required List<RideModel> model}) async {
  //   final workbook = Workbook();
  //   final sheet = workbook.worksheets[0];

  //   final headers = [
  //     "Sno",
  //     "Ride By",
  //     "Start Time",
  //     "End Time",
  //     "Start Point",
  //     "End Point",
  //     "Time Taken",
  //     "Distance Covered",
  //   ];

  //   // Header row
  //   for (int i = 0; i < headers.length; i++) {
  //     sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
  //   }

  //   for (int row = 0; row < model.length; row++) {
  //     final product = model[row];
  //     final excelRow = row + 2;

  //     sheet.getRangeByIndex(excelRow, 1).setNumber(row + 1);
  //     sheet.getRangeByIndex(excelRow, 2).setText(product.userName);
  //     sheet
  //         .getRangeByIndex(excelRow, 3)
  //         .setText(DateFormat('dd-MM-yyyy hh:mm a').format(product.created));
  //     sheet
  //         .getRangeByIndex(excelRow, 4)
  //         .setText(DateFormat('dd-MM-yyyy hh:mm a').format(product.modified));

  //     sheet.getRangeByIndex(excelRow, 5).setText(
  //         "${product.points.first.latitude}, ${product.points.first.longitude}");

  //     sheet.getRangeByIndex(excelRow, 6).setText(
  //         "${product.points.last.latitude}, ${product.points.last.longitude}");

  //     sheet
  //         .getRangeByIndex(excelRow, 7)
  //         .setText(formatDuration(product.modified.difference(product.created)));

  //     sheet.getRangeByIndex(excelRow, 8).setText(
  //         "${LocationService.calculateTotalDistance(product.points.map((e) {
  //           return LatLng(e.latitude, e.longitude);
  //         }).toList()).toStringAsFixed(2)} KM");
  //   }

  //   sheet.autoFitColumn(1);
  //   sheet.autoFitColumn(8);

  //   final bytes = workbook.saveAsStream();
  //   workbook.dispose();

  //   FileHelper.launchFile(
  //     bt: bytes,
  //     nf: false,
  //     fn: "Ride Report.xlsx",
  //     name: "Ride Report",
  //   );
  // }

  // static Future workTimeReportExport({
  //   required List<WorktimeModel> model,
  // }) async {
  //   final workbook = Workbook();
  //   final sheet = workbook.worksheets[0];

  //   final headers = [
  //     "Sno",
  //     "Name",
  //     "Clock In",
  //     "Clock Out",
  //     "Total Breaks",
  //     "Total Working Hours",
  //   ];

  //   for (int i = 0; i < headers.length; i++) {
  //     sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
  //   }

  //   for (int row = 0; row < model.length; row++) {
  //     final product = model[row];
  //     final excelRow = row + 2;

  //     Duration totalBreaks = Duration.zero;
  //     Duration totalWorktime = Duration.zero;

  //     for (var breakEntry in product.breaks.entries) {
  //       final start = breakEntry.value["start"].toDate();
  //       final end = breakEntry.value["end"].toDate();
  //       totalBreaks += end.difference(start);
  //     }

  //     if (product.clockOut != null) {
  //       totalWorktime =
  //           product.clockOut!.difference(product.clockIn) - totalBreaks;
  //     }

  //     sheet.getRangeByIndex(excelRow, 1).setNumber(row + 1);
  //     sheet.getRangeByIndex(excelRow, 2).setText(product.userName);
  //     sheet
  //         .getRangeByIndex(excelRow, 3)
  //         .setText(DateFormat('dd-MM-yyyy hh:mm a').format(product.clockIn));
  //     sheet
  //         .getRangeByIndex(excelRow, 4)
  //         .setText(
  //           product.clockOut != null
  //               ? DateFormat('dd-MM-yyyy hh:mm a').format(product.clockOut!)
  //               : "",
  //         );
  //     sheet.getRangeByIndex(excelRow, 5).setText(formatDuration(totalBreaks));
  //     sheet.getRangeByIndex(excelRow, 6).setText(formatDuration(totalWorktime));
  //   }

  //   final bytes = workbook.saveAsStream();
  //   workbook.dispose();

  //   FileHelper.launchFile(
  //     bt: bytes,
  //     nf: false,
  //     fn: "Worktime Report.xlsx",
  //     name: "Worktime Report",
  //   );
  // }

  // static Future payslipReportExport({
  //   required SalaryModel salary,
  //   required EmployeeModel? employee,
  // }) async {
  //   final workbook = Workbook();
  //   final sheet = workbook.worksheets[0];

  //   // Set Column Widths for a premium structured layout
  //   sheet.getRangeByName('A1').columnWidth = 28.0; // Earnings Item
  //   sheet.getRangeByName('B1').columnWidth = 16.0; // Earnings Amount
  //   sheet.getRangeByName('C1').columnWidth = 4.0;  // Spacing Column
  //   sheet.getRangeByName('D1').columnWidth = 28.0; // Deductions Item
  //   sheet.getRangeByName('E1').columnWidth = 16.0; // Deductions Amount

  //   // 1. Corporate Header
  //   final titleRange = sheet.getRangeByName('A1:E1');
  //   titleRange.merge();
  //   titleRange.setText("SRISOFTWAREZ - PAYSLIP");
  //   titleRange.cellStyle.fontSize = 16;
  //   titleRange.cellStyle.bold = true;
  //   titleRange.cellStyle.backColor = '#1E3A8A'; // Deep Navy Blue
  //   titleRange.cellStyle.fontColor = '#FFFFFF';
  //   titleRange.cellStyle.hAlign = HAlignType.center;
  //   titleRange.cellStyle.vAlign = VAlignType.center;
  //   sheet.getRangeByName('A1').rowHeight = 35.0;

  //   // Subtitle
  //   final monthCodeStr = salary.salaryNumber; // e.g. 202605
  //   String monthName = "N/A";
  //   if (monthCodeStr.length >= 6) {
  //     final year = monthCodeStr.substring(0, 4);
  //     final monthIndex = int.tryParse(monthCodeStr.substring(4, 6)) ?? 1;
  //     const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  //     if (monthIndex >= 1 && monthIndex <= 12) {
  //       monthName = "${months[monthIndex - 1]} $year";
  //     }
  //   } else {
  //     monthName = monthCodeStr;
  //   }

  //   final subtitleRange = sheet.getRangeByName('A2:E2');
  //   subtitleRange.merge();
  //   subtitleRange.setText("Salary Payslip for the period of $monthName");
  //   subtitleRange.cellStyle.fontSize = 11;
  //   subtitleRange.cellStyle.italic = true;
  //   subtitleRange.cellStyle.backColor = '#3B82F6'; // Medium Royal Blue
  //   subtitleRange.cellStyle.fontColor = '#FFFFFF';
  //   subtitleRange.cellStyle.hAlign = HAlignType.center;
  //   subtitleRange.cellStyle.vAlign = VAlignType.center;
  //   sheet.getRangeByName('A2').rowHeight = 22.0;

  //   // 2. Employee Info Section
  //   final infoTitleRange = sheet.getRangeByName('A4:E4');
  //   infoTitleRange.merge();
  //   infoTitleRange.setText("EMPLOYEE INFORMATION");
  //   infoTitleRange.cellStyle.fontSize = 11;
  //   infoTitleRange.cellStyle.bold = true;
  //   infoTitleRange.cellStyle.backColor = '#F3F4F6';
  //   infoTitleRange.cellStyle.hAlign = HAlignType.left;
  //   infoTitleRange.cellStyle.vAlign = VAlignType.center;
  //   sheet.getRangeByName('A4').rowHeight = 20.0;

  //   // Line 1: Employee ID & Name
  //   sheet.getRangeByName('A5').setText("Employee ID:");
  //   sheet.getRangeByName('A5').cellStyle.bold = true;
  //   sheet.getRangeByName('B5').setText(employee?.employeeId ?? salary.employeeId);

  //   sheet.getRangeByName('D5').setText("Employee Name:");
  //   sheet.getRangeByName('D5').cellStyle.bold = true;
  //   sheet.getRangeByName('E5').setText(employee?.name ?? "N/A");

  //   // Line 2: Designation & Department
  //   sheet.getRangeByName('A6').setText("Designation:");
  //   sheet.getRangeByName('A6').cellStyle.bold = true;
  //   sheet.getRangeByName('B6').setText(employee?.designation ?? "N/A");

  //   sheet.getRangeByName('D6').setText("Department:");
  //   sheet.getRangeByName('D6').cellStyle.bold = true;
  //   sheet.getRangeByName('E6').setText(employee?.department?.join(', ') ?? "N/A");

  //   // Line 3: Pay Period & Working Days
  //   final fromDateStr = salary.salaryFromDate.isNotEmpty
  //       ? DateFormat('dd-MM-yyyy').format(DateTime.parse(salary.salaryFromDate))
  //       : "N/A";
  //   final toDateStr = salary.salaryToDate.isNotEmpty
  //       ? DateFormat('dd-MM-yyyy').format(DateTime.parse(salary.salaryToDate))
  //       : "N/A";

  //   sheet.getRangeByName('A7').setText("Pay Duration:");
  //   sheet.getRangeByName('A7').cellStyle.bold = true;
  //   sheet.getRangeByName('B7').setText("$fromDateStr to $toDateStr");

  //   sheet.getRangeByName('D7').setText("Working / Leave Days:");
  //   sheet.getRangeByName('D7').cellStyle.bold = true;
  //   sheet.getRangeByName('E7').setText("${salary.workingDays} days / ${salary.leaveDays} leaves");

  //   // Add style to employee info block (A5:E7)
  //   final infoBlock = sheet.getRangeByName('A5:E7');
  //   infoBlock.cellStyle.fontSize = 10;

  //   // 3. Earnings & Deductions Headers
  //   final earnHeader = sheet.getRangeByName('A9');
  //   earnHeader.setText("EARNINGS");
  //   earnHeader.cellStyle.bold = true;
  //   earnHeader.cellStyle.backColor = '#10B981'; // Green
  //   earnHeader.cellStyle.fontColor = '#FFFFFF';
  //   earnHeader.cellStyle.hAlign = HAlignType.center;

  //   final earnAmountHeader = sheet.getRangeByName('B9');
  //   earnAmountHeader.setText("AMOUNT (₹)");
  //   earnAmountHeader.cellStyle.bold = true;
  //   earnAmountHeader.cellStyle.backColor = '#10B981';
  //   earnAmountHeader.cellStyle.fontColor = '#FFFFFF';
  //   earnAmountHeader.cellStyle.hAlign = HAlignType.right;

  //   final dedHeader = sheet.getRangeByName('D9');
  //   dedHeader.setText("DEDUCTIONS");
  //   dedHeader.cellStyle.bold = true;
  //   dedHeader.cellStyle.backColor = '#EF4444'; // Red
  //   dedHeader.cellStyle.fontColor = '#FFFFFF';
  //   dedHeader.cellStyle.hAlign = HAlignType.center;

  //   final dedAmountHeader = sheet.getRangeByName('E9');
  //   dedAmountHeader.setText("AMOUNT (₹)");
  //   dedAmountHeader.cellStyle.bold = true;
  //   dedAmountHeader.cellStyle.backColor = '#EF4444';
  //   dedAmountHeader.cellStyle.fontColor = '#FFFFFF';
  //   dedAmountHeader.cellStyle.hAlign = HAlignType.right;

  //   sheet.getRangeByName('A9').rowHeight = 22.0;

  //   // 4. Earnings & Deductions Details Rows
  //   // Row 10: Basic / Earned & PF
  //   sheet.getRangeByName('A10').setText("Basic & Earned Salary");
  //   sheet.getRangeByName('B10').setNumber(double.tryParse(salary.earnAmount) ?? 0);
  //   sheet.getRangeByName('B10').numberFormat = '₹#,##0.00';
  //   sheet.getRangeByName('D10').setText("Provident Fund (PF)");
  //   sheet.getRangeByName('E10').setNumber(double.tryParse(salary.pfAmount) ?? 0);
  //   sheet.getRangeByName('E10').numberFormat = '₹#,##0.00';

  //   // Row 11: OT & ESI
  //   sheet.getRangeByName('A11').setText("Overtime Allowance (${salary.otHours} hrs)");
  //   sheet.getRangeByName('B11').setNumber(double.tryParse(salary.otAmount) ?? 0);
  //   sheet.getRangeByName('B11').numberFormat = '₹#,##0.00';
  //   sheet.getRangeByName('D11').setText("Employee State Ins (ESI)");
  //   sheet.getRangeByName('E11').setNumber(double.tryParse(salary.esiAmount) ?? 0);
  //   sheet.getRangeByName('E11').numberFormat = '₹#,##0.00';

  //   // Row 12: Incentive & Advance
  //   sheet.getRangeByName('A12').setText("Incentive & Performance Bonus");
  //   sheet.getRangeByName('B12').setNumber(double.tryParse(salary.incentive) ?? 0);
  //   sheet.getRangeByName('B12').numberFormat = '₹#,##0.00';
  //   sheet.getRangeByName('D12').setText("Advance Salary Deductions");
  //   sheet.getRangeByName('E12').setNumber(double.tryParse(salary.advanceDeduction) ?? 0);
  //   sheet.getRangeByName('E12').numberFormat = '₹#,##0.00';

  //   // Row 13: Empty Earning & Other Deductions
  //   sheet.getRangeByName('A13').setText("");
  //   sheet.getRangeByName('B13').setText("");
  //   sheet.getRangeByName('D13').setText("Other/Permission Deductions");
  //   sheet.getRangeByName('E13').setNumber(double.tryParse(salary.otherDeduction) ?? 0);
  //   sheet.getRangeByName('E13').numberFormat = '₹#,##0.00';

  //   // Row 14: Totals
  //   final grossLabel = sheet.getRangeByName('A14');
  //   grossLabel.setText("Gross Earnings");
  //   grossLabel.cellStyle.bold = true;
  //   grossLabel.cellStyle.backColor = '#E5F3EB';
  //   final grossValue = sheet.getRangeByName('B14');
  //   grossValue.setNumber(double.tryParse(salary.grossPay) ?? 0);
  //   grossValue.cellStyle.bold = true;
  //   grossValue.cellStyle.backColor = '#E5F3EB';
  //   grossValue.numberFormat = '₹#,##0.00';

  //   final dedLabel = sheet.getRangeByName('D14');
  //   dedLabel.setText("Total Deductions");
  //   dedLabel.cellStyle.bold = true;
  //   dedLabel.cellStyle.backColor = '#FDF2F2';
  //   final dedValue = sheet.getRangeByName('E14');
  //   dedValue.setNumber(double.tryParse(salary.totalDeduction) ?? 0);
  //   dedValue.cellStyle.bold = true;
  //   dedValue.cellStyle.backColor = '#FDF2F2';
  //   dedValue.numberFormat = '₹#,##0.00';

  //   sheet.getRangeByName('A14').rowHeight = 22.0;

  //   // Apply styles to table
  //   final tableBodyRange = sheet.getRangeByName('A9:E14');
  //   tableBodyRange.cellStyle.fontSize = 9.5;

  //   // 5. Net Salary Highlight Banner
  //   final netPayRange = sheet.getRangeByName('A16:E16');
  //   netPayRange.merge();
  //   final netPayVal = double.tryParse(salary.netPay) ?? 0;
  //   final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  //   netPayRange.setText("NET TAKE-HOME PAYOUT:  ${formatter.format(netPayVal)}");
  //   netPayRange.cellStyle.fontSize = 13;
  //   netPayRange.cellStyle.bold = true;
  //   netPayRange.cellStyle.backColor = '#D1FAE5'; // Light Emerald Green
  //   netPayRange.cellStyle.fontColor = '#065F46'; // Dark Forest Green
  //   netPayRange.cellStyle.hAlign = HAlignType.center;
  //   netPayRange.cellStyle.vAlign = VAlignType.center;
  //   sheet.getRangeByName('A16').rowHeight = 32.0;

  //   // Amount in Words
  //   final wordsRange = sheet.getRangeByName('A17:E17');
  //   wordsRange.merge();
  //   wordsRange.setText("Amount in Words: Rupees ${numberToWords(netPayVal.toInt())} Only");
  //   wordsRange.cellStyle.fontSize = 9.5;
  //   wordsRange.cellStyle.italic = true;
  //   wordsRange.cellStyle.hAlign = HAlignType.center;
  //   wordsRange.cellStyle.vAlign = VAlignType.center;
  //   sheet.getRangeByName('A17').rowHeight = 18.0;

  //   // 6. Footer disclaimer
  //   final footerRange = sheet.getRangeByName('A19:E19');
  //   footerRange.merge();
  //   footerRange.setText("This is an electronically generated payslip statement by Srisoftwarez.com and does not require a physical signature.");
  //   footerRange.cellStyle.fontSize = 8.5;
  //   footerRange.cellStyle.fontColor = '#6B7280';
  //   footerRange.cellStyle.hAlign = HAlignType.center;
  //   sheet.getRangeByName('A19').rowHeight = 16.0;

  //   // Save and launch
  //   final bytes = workbook.saveAsStream();
  //   workbook.dispose();

  //   final safeEmployeeName = (employee?.name ?? salary.employeeId)
  //       .replaceAll(RegExp(r'[^\w\s\-]'), '')
  //       .trim();
  //   final fileName = "Payslip_${safeEmployeeName}_$monthCodeStr.xlsx";

  //   await FileHelper.launchFile(
  //     bt: bytes,
  //     nf: false,
  //     fn: fileName,
  //     name: "Payslip Report",
  //   );
  // }

  // A premium static helper for Rupees number-to-words conversion
  static String numberToWords(int number) {
    if (number == 0) return "Zero";

    final units = [
      "",
      "One",
      "Two",
      "Three",
      "Four",
      "Five",
      "Six",
      "Seven",
      "Eight",
      "Nine",
      "Ten",
      "Eleven",
      "Twelve",
      "Thirteen",
      "Fourteen",
      "Fifteen",
      "Sixteen",
      "Seventeen",
      "Eighteen",
      "Nineteen",
    ];

    final tens = [
      "",
      "",
      "Twenty",
      "Thirty",
      "Forty",
      "Fifty",
      "Sixty",
      "Seventy",
      "Eighty",
      "Ninety",
    ];

    String convertLessThanOneThousand(int n) {
      if (n == 0) return "";

      if (n < 20) {
        return units[n];
      }

      if (n < 100) {
        final unitPart = n % 10;
        return "${tens[n ~/ 10]}${unitPart > 0 ? " ${units[unitPart]}" : ""}";
      }

      final tensPart = n % 100;
      return "${units[n ~/ 100]} Hundred${tensPart > 0 ? " ${convertLessThanOneThousand(tensPart)}" : ""}";
    }

    int temp = number;
    String words = "";

    if (temp >= 10000000) {
      // Crores
      final crores = temp ~/ 10000000;
      words += "${convertLessThanOneThousand(crores)} Crore ";
      temp %= 10000000;
    }

    if (temp >= 100000) {
      // Lakhs
      final lakhs = temp ~/ 100000;
      words += "${convertLessThanOneThousand(lakhs)} Lakh ";
      temp %= 100000;
    }

    if (temp >= 1000) {
      // Thousands
      final thousands = temp ~/ 1000;
      words += "${convertLessThanOneThousand(thousands)} Thousand ";
      temp %= 1000;
    }

    if (temp > 0) {
      words += convertLessThanOneThousand(temp);
    }

    return words.trim();
  }
}
