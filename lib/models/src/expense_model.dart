import 'package:flutter/material.dart' show Color;
import '/models/src/file_model.dart';
import '/models/src/user_data_model.dart';

/// One expense bill (expenses.php).
class ExpenseModel {
  final String uid;
  final String expenseNumber;
  final String masterCompanyId;
  final String masterCompanyName;
  final String categoryId;
  final String categoryName;
  final Color categoryColor;
  final double amount;
  final String paymentMode;
  final String upiNumber;
  final DateTime expenseDate;
  final String description;
  final List<FileModel> attachments;

  /// Attachment objects exactly as the server stored them, so an edit can send
  /// the untouched ones back unchanged.
  final List<Map<String, dynamic>> rawAttachments;
  final bool isCancelled;
  final String cancellationRemarks;
  final String cancelledByName;
  final DateTime? cancelledAt;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    required this.uid,
    required this.expenseNumber,
    required this.masterCompanyId,
    required this.masterCompanyName,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.amount,
    required this.paymentMode,
    this.upiNumber = '',
    required this.expenseDate,
    this.description = '',
    this.attachments = const [],
    this.rawAttachments = const [],
    this.isCancelled = false,
    this.cancellationRemarks = '',
    this.cancelledByName = '',
    this.cancelledAt,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// Expense Category master (masters.php?type=expense_category).
class ExpenseCategoryModel {
  final String? uid;
  final String name;
  final String description;
  final Color color;

  /// Number of (non deleted) expense bills using this category.
  final int expenseCount;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseCategoryModel({
    this.uid,
    required this.name,
    this.description = '',
    this.color = const Color(0xFF2563EB),
    this.expenseCount = 0,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// Tenant-wide totals returned with the expense list.
class ExpenseStats {
  final int totalCount;
  final int activeCount;
  final int cancelledCount;
  final double totalActiveAmount;
  final double totalCancelledAmount;
  final double grandTotalAmount;

  const ExpenseStats({
    this.totalCount = 0,
    this.activeCount = 0,
    this.cancelledCount = 0,
    this.totalActiveAmount = 0,
    this.totalCancelledAmount = 0,
    this.grandTotalAmount = 0,
  });
}

class ExpenseListResult {
  final List<ExpenseModel> items;
  final ExpenseStats stats;
  const ExpenseListResult(this.items, this.stats);
}

/// id + display name (+ colour) used by the report filters.
class ExpenseLookupItem {
  final String id;
  final String name;
  final Color color;
  const ExpenseLookupItem(this.id, this.name, [this.color = const Color(0xFF2563EB)]);
}

class ExpenseReportSummary {
  final double totalSpent;
  final int totalBills;
  final int activeCount;
  final int cancelledCount;
  final double cancelledAmount;
  final double avgBillAmount;
  final String topCategory;

  const ExpenseReportSummary({
    this.totalSpent = 0,
    this.totalBills = 0,
    this.activeCount = 0,
    this.cancelledCount = 0,
    this.cancelledAmount = 0,
    this.avgBillAmount = 0,
    this.topCategory = 'None',
  });
}

/// One slice of the "spend by category" breakdown.
class ExpenseReportBucket {
  final String name;
  final Color color;
  final double amount;
  final int billCount;
  final double percent;
  const ExpenseReportBucket({
    required this.name,
    required this.color,
    required this.amount,
    required this.billCount,
    required this.percent,
  });
}

class ExpenseReportData {
  final ExpenseReportSummary summary;
  final List<ExpenseModel> items;
  final List<ExpenseReportBucket> byCategory;
  final List<ExpenseLookupItem> companies;
  final List<ExpenseLookupItem> categories;
  final List<String> paymentModes;
  final DateTime? defaultFrom;
  final DateTime? defaultTo;

  const ExpenseReportData({
    required this.summary,
    required this.items,
    required this.byCategory,
    required this.companies,
    required this.categories,
    required this.paymentModes,
    this.defaultFrom,
    this.defaultTo,
  });
}