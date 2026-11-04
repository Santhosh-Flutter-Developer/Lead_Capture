// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class SalaryModel {
  String salaryNumber;
  String employeeId;
  String? permissionId;
  String workingDays;
  String leaveDays;
  String otHours;
  String earnAmount;
  String otAmount;
  String incentive;
  String grossPay;
  String otherDeduction;
  String pfAmount;
  String esiAmount;
  String advanceDeduction;
  String totalDeduction;
  String netPay;
  String salaryFromDate;
  String salaryToDate;
  SalaryModel({
    required this.salaryNumber,
    required this.employeeId,
    this.permissionId,
    required this.workingDays,
    required this.leaveDays,
    required this.otHours,
    required this.earnAmount,
    required this.otAmount,
    required this.incentive,
    required this.grossPay,
    required this.otherDeduction,
    required this.pfAmount,
    required this.esiAmount,
    required this.advanceDeduction,
    required this.totalDeduction,
    required this.netPay,
    required this.salaryFromDate,
    required this.salaryToDate,
  });

  SalaryModel copyWith({
    String? salaryNumber,
    String? employeeId,
    String? permissionId,
    String? workingDays,
    String? leaveDays,
    String? otHours,
    String? earnAmount,
    String? otAmount,
    String? incentive,
    String? grossPay,
    String? otherDeduction,
    String? pfAmount,
    String? esiAmount,
    String? advanceDeduction,
    String? totalDeduction,
    String? netPay,
    String? salaryFromDate,
    String? salaryToDate,
  }) {
    return SalaryModel(
      salaryNumber: salaryNumber ?? this.salaryNumber,
      employeeId: employeeId ?? this.employeeId,
      permissionId: permissionId ?? this.permissionId,
      workingDays: workingDays ?? this.workingDays,
      leaveDays: leaveDays ?? this.leaveDays,
      otHours: otHours ?? this.otHours,
      earnAmount: earnAmount ?? this.earnAmount,
      otAmount: otAmount ?? this.otAmount,
      incentive: incentive ?? this.incentive,
      grossPay: grossPay ?? this.grossPay,
      otherDeduction: otherDeduction ?? this.otherDeduction,
      pfAmount: pfAmount ?? this.pfAmount,
      esiAmount: esiAmount ?? this.esiAmount,
      advanceDeduction: advanceDeduction ?? this.advanceDeduction,
      totalDeduction: totalDeduction ?? this.totalDeduction,
      netPay: netPay ?? this.netPay,
      salaryFromDate: salaryFromDate ?? this.salaryFromDate,
      salaryToDate: salaryToDate ?? this.salaryToDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'salary_number': salaryNumber,
      'employee_id': employeeId,
      'permissionId': permissionId,
      'working_days': workingDays,
      'leave_days': leaveDays,
      'ot_hours': otHours,
      'earn_amount': earnAmount,
      'ot_amount': otAmount,
      'incentive': incentive,
      'gross_pay': grossPay,
      'other_deduction': otherDeduction,
      'pf_amount': pfAmount,
      'esi_amount': esiAmount,
      'advance_deduction': advanceDeduction,
      'total_deduction': totalDeduction,
      'net_pay': netPay,
      'salary_from_date': salaryFromDate,
      'salary_to_date': salaryToDate,
    };
  }

  factory SalaryModel.fromMap(Map<String, dynamic> map) {
    return SalaryModel(
      salaryNumber: map['salary_number']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      permissionId: map['permissionId']?.toString() ?? '',
      workingDays: map['working_days']?.toString() ?? '0',
      leaveDays: map['leave_days']?.toString() ?? '0',
      otHours: map['ot_hours']?.toString() ?? '0',
      earnAmount: map['earn_amount']?.toString() ?? '0',
      otAmount: map['ot_amount']?.toString() ?? '0',
      incentive: map['incentive']?.toString() ?? '0',
      grossPay: map['gross_pay']?.toString() ?? '0',
      otherDeduction: map['other_deduction']?.toString() ?? '0',
      pfAmount: map['pf_amount']?.toString() ?? '0',
      esiAmount: map['esi_amount']?.toString() ?? '0',
      advanceDeduction: map['advance_deduction']?.toString() ?? '0',
      totalDeduction: map['total_deduction']?.toString() ?? '0',
      netPay: map['net_pay']?.toString() ?? '0',
      salaryFromDate: map['salary_from_date']?.toString() ?? '',
      salaryToDate: map['salary_to_date']?.toString() ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory SalaryModel.fromJson(String source) =>
      SalaryModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SalaryModel(salaryNumber: $salaryNumber, workingDays: $workingDays, leaveDays: $leaveDays, otHours: $otHours, earnAmount: $earnAmount, otAmount: $otAmount, incentive: $incentive, grossPay: $grossPay, otherDeduction: $otherDeduction, pfAmount: $pfAmount, esiAmount: $esiAmount, advanceDeduction: $advanceDeduction, totalDeduction: $totalDeduction, netPay: $netPay, salaryFromDate: $salaryFromDate, salaryToDate: $salaryToDate)';
  }

  @override
  bool operator ==(covariant SalaryModel other) {
    if (identical(this, other)) return true;

    return other.salaryNumber == salaryNumber &&
        other.workingDays == workingDays &&
        other.leaveDays == leaveDays &&
        other.otHours == otHours &&
        other.earnAmount == earnAmount &&
        other.otAmount == otAmount &&
        other.incentive == incentive &&
        other.grossPay == grossPay &&
        other.otherDeduction == otherDeduction &&
        other.pfAmount == pfAmount &&
        other.esiAmount == esiAmount &&
        other.advanceDeduction == advanceDeduction &&
        other.totalDeduction == totalDeduction &&
        other.netPay == netPay &&
        other.salaryFromDate == salaryFromDate &&
        other.salaryToDate == salaryToDate;
  }

  @override
  int get hashCode {
    return salaryNumber.hashCode ^
        workingDays.hashCode ^
        leaveDays.hashCode ^
        otHours.hashCode ^
        earnAmount.hashCode ^
        otAmount.hashCode ^
        incentive.hashCode ^
        grossPay.hashCode ^
        otherDeduction.hashCode ^
        pfAmount.hashCode ^
        esiAmount.hashCode ^
        advanceDeduction.hashCode ^
        totalDeduction.hashCode ^
        netPay.hashCode ^
        salaryFromDate.hashCode ^
        salaryToDate.hashCode;
  }

  double get workingDaysValue => double.tryParse(workingDays) ?? 0;

  double get leaveDaysValue => double.tryParse(leaveDays) ?? 0;

  double get otHoursValue => double.tryParse(otHours) ?? 0;

  double get earnAmountValue => double.tryParse(earnAmount) ?? 0;

  double get otAmountValue => double.tryParse(otAmount) ?? 0;

  double get incentiveValue => double.tryParse(incentive) ?? 0;

  double get grossPayValue => double.tryParse(grossPay) ?? 0;

  double get otherDeductionValue => double.tryParse(otherDeduction) ?? 0;

  double get pfAmountValue => double.tryParse(pfAmount) ?? 0;

  double get esiAmountValue => double.tryParse(esiAmount) ?? 0;

  double get advanceDeductionValue => double.tryParse(advanceDeduction) ?? 0;

  double get totalDeductionValue => double.tryParse(totalDeduction) ?? 0;

  double get netPayValue => double.tryParse(netPay) ?? 0;

  /// salary start date
  DateTime get fromDate => DateTime.tryParse(salaryFromDate) ?? DateTime.now();

  /// salary end date
  DateTime get toDate => DateTime.tryParse(salaryToDate) ?? DateTime.now();
}
