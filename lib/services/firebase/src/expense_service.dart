import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

/// API row -> model mappers for the Expense module.
class ExpenseMappers {
  ExpenseMappers._();

  static Color _color(dynamic v) => Color(ApiMappers.colorFromServer(v, 0xFF2563EB));

  static ExpenseModel expense(Map<String, dynamic> m) {
    final rawList = Js.mapList(m['attachments_list']).isNotEmpty
        ? Js.mapList(m['attachments_list'])
        : Js.mapList(m['attachments']);
    return ExpenseModel(
      uid: Js.s(m['uid']),
      expenseNumber: Js.s(m['expense_number']),
      masterCompanyId: Js.s(m['master_company_id']),
      masterCompanyName: Js.s(m['master_company_name']),
      categoryId: Js.s(m['category_id']),
      categoryName: Js.s(m['category_name']),
      categoryColor: _color(m['category_color']),
      amount: Js.d(m['amount']),
      paymentMode: Js.s(m['payment_mode']),
      upiNumber: Js.s(m['upi_number']),
      expenseDate: Js.dt(m['expense_date']) ?? DateTime.now(),
      description: Js.s(m['description']),
      attachments: rawList.map(CrmMappers.file).toList(),
      rawAttachments: rawList,
      isCancelled: Js.b(m['is_cancelled']),
      cancellationRemarks: Js.s(m['cancellation_remarks']),
      cancelledByName: Js.s(m['cancelled_by_name']),
      cancelledAt: Js.dtUtc(m['cancelled_at']),
      createdBy: ApiMappers.createdBy(m),
      createdAt: Js.dtUtc(m['created_at']),
      updatedAt: Js.dtUtc(m['updated_at']),
    );
  }

  static ExpenseCategoryModel category(Map<String, dynamic> m) => ExpenseCategoryModel(
        uid: Js.s(m['uid']),
        name: Js.s(m['name']),
        description: Js.s(m['description']),
        color: _color(m['color']),
        expenseCount: Js.i(m['expense_count']) ?? 0,
        createdBy: ApiMappers.createdBy(m),
        createdAt: Js.dtUtc(m['created_at']),
        updatedAt: Js.dtUtc(m['updated_at']),
      );

  static ExpenseStats stats(Map<String, dynamic> m) => ExpenseStats(
        totalCount: Js.i(m['total_count']) ?? 0,
        activeCount: Js.i(m['active_count']) ?? 0,
        cancelledCount: Js.i(m['cancelled_count']) ?? 0,
        totalActiveAmount: Js.d(m['total_active_amount']),
        totalCancelledAmount: Js.d(m['total_cancelled_amount']),
        grandTotalAmount: Js.d(m['grand_total_amount']),
      );
}

Never _fail(String prefix, Object e, StackTrace st) {
  ErrorService.recordError(e, st);
  debugPrint('$prefix: $e\n$st');
  if (e is ApiException) throw e.message;
  if (e is String) throw e;
  throw '$prefix: $e';
}

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Expense bills – backed by expenses.php.
/// Permission pages: "Expenses" (view / create / edit / delete = cancel / export).
class ExpenseService {
  /// Every expense matching the filters (all pages are fetched; the screen
  /// pages / sorts / searches locally like the other listings).
  static Future<ExpenseListResult> list({
    DateTime? from,
    DateTime? to,
    String? masterCompanyId,
    String? categoryId,
    String? paymentMode,
    String status = 'all',
  }) async {
    try {
      final items = <ExpenseModel>[];
      var stats = const ExpenseStats();
      var page = 1;
      var totalPages = 1;
      do {
        final res = (await ExpensesApiService.call('list', {
          if (from != null) 'from_date': _ymd(from),
          if (to != null) 'to_date': _ymd(to),
          if (masterCompanyId != null) 'master_company_id': masterCompanyId,
          if (categoryId != null) 'category_id': categoryId,
          if (paymentMode != null) 'payment_mode': paymentMode,
          'status': status,
          'page': page,
          'limit': 500,
        })).ensureSuccess();
        final d = res.dataMap;
        items.addAll(Js.mapList(d['items']).map(ExpenseMappers.expense));
        stats = ExpenseMappers.stats(Js.m(d['stats']));
        totalPages = Js.i(d['total_pages']) ?? 1;
        page++;
      } while (page <= totalPages && page <= 40);
      return ExpenseListResult(items, stats);
    } catch (e, st) {
      _fail('Error fetching expenses', e, st);
    }
  }

  static Future<ExpenseModel> get({required String uid}) async {
    try {
      final res = (await ExpensesApiService.call('get', {'uid': uid})).ensureSuccess();
      return ExpenseMappers.expense(res.dataMap);
    } catch (e, st) {
      _fail('Error fetching expense', e, st);
    }
  }

  /// Creates (uid == null) or updates an expense.
  /// [attachments] are the attachment objects to keep on the record.
  static Future<void> save({
    String? uid,
    required String masterCompanyId,
    required String categoryId,
    required double amount,
    required String paymentMode,
    String upiNumber = '',
    required DateTime expenseDate,
    String description = '',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      final body = <String, dynamic>{
        if (uid != null && uid.isNotEmpty) 'uid': uid,
        'master_company_id': masterCompanyId,
        'category_id': categoryId,
        'amount': amount,
        'payment_mode': paymentMode,
        'upi_number': upiNumber,
        'expense_date': _ymd(expenseDate),
        'description': description,
        'attachments': attachments,
      };
      (await ExpensesApiService.call(uid == null || uid.isEmpty ? 'create' : 'update', body))
          .ensureSuccess();
      ApiLive.changed({'expenses', 'expense_category'});
    } catch (e, st) {
      _fail('Error saving expense', e, st);
    }
  }

  /// The server never deletes an expense; it is cancelled with remarks.
  static Future<void> cancel({required String uid, required String remarks}) async {
    try {
      (await ExpensesApiService.call('cancel', {'uid': uid, 'remarks': remarks})).ensureSuccess();
      ApiLive.changed({'expenses', 'expense_category'});
    } catch (e, st) {
      _fail('Error cancelling expense', e, st);
    }
  }

  static Future<int> bulkCancel({required List<String> uids, required String remarks}) async {
    try {
      final res = (await ExpensesApiService.call('bulk_cancel', {'uids': uids, 'remarks': remarks}))
          .ensureSuccess();
      ApiLive.changed({'expenses', 'expense_category'});
      return Js.i(res.dataMap['cancelled_count']) ?? 0;
    } catch (e, st) {
      _fail('Error cancelling expenses', e, st);
    }
  }
}

/// Expense Category master – backed by masters.php?type=expense_category.
/// Permission page: "Expense Category".
class ExpenseCategoryService {
  static const String _type = MasterTypes.expenseCategory;

  static Future<List<ExpenseCategoryModel>> getAll() async {
    try {
      final res = (await MastersApiService.list(_type)).ensureSuccess();
      return res.dataList.map((r) => ExpenseMappers.category(Js.m(r))).toList();
    } catch (e, st) {
      _fail('Error fetching expense categories', e, st);
    }
  }

  static Map<String, dynamic> _body(ExpenseCategoryModel m) => {
        'name': m.name,
        'description': m.description,
        'color': ApiMappers.colorToServer(m.color.toARGB32()),
      };

  static Future<void> create(ExpenseCategoryModel m) async {
    try {
      (await MastersApiService.create(_type, _body(m))).ensureSuccess();
      ApiLive.changed({_type, 'expense_category'});
    } catch (e, st) {
      _fail('Error creating expense category', e, st);
    }
  }

  static Future<void> update(String uid, ExpenseCategoryModel m) async {
    try {
      (await MastersApiService.update(_type, uid, _body(m))).ensureSuccess();
      ApiLive.changed({_type, 'expense_category', 'expenses'});
    } catch (e, st) {
      _fail('Error updating expense category', e, st);
    }
  }

  /// The server refuses (with the reason) when expenses use the category.
  static Future<void> delete(String uid) async {
    try {
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLive.changed({_type, 'expense_category'});
    } catch (e, st) {
      _fail('Error deleting expense category', e, st);
    }
  }

  /// Null when the name is free (case-insensitive).
  static Future<String?> checkExists({required String name, String? excludeUid}) async {
    final n = name.trim().toLowerCase();
    for (final c in await getAll()) {
      if (excludeUid != null && c.uid == excludeUid) continue;
      if (c.name.trim().toLowerCase() == n) return 'Expense category name already exists';
    }
    return null;
  }
}

/// Expense Report – backed by expense_report.php.
/// Permission page: "Expense Report" (or "Expenses").
class ExpenseReportService {
  static Future<ExpenseReportData> fetch({
    DateTime? from,
    DateTime? to,
    String? masterCompanyId,
    String? categoryId,
    String? paymentMode,
    String status = 'active',
  }) async {
    try {
      final res = (await ExpenseReportApiService.call({
        if (from != null) 'from_date': _ymd(from),
        if (to != null) 'to_date': _ymd(to),
        if (masterCompanyId != null) 'master_company_id': masterCompanyId,
        if (categoryId != null) 'category_id': categoryId,
        if (paymentMode != null) 'payment_mode': paymentMode,
        'status': status,
      })).ensureSuccess();
      final d = res.dataMap;
      final s = Js.m(d['summary']);
      final lk = Js.m(d['lookups']);
      final dates = Js.m(d['default_dates']);
      return ExpenseReportData(
        summary: ExpenseReportSummary(
          totalSpent: Js.d(s['total_spent']),
          totalBills: Js.i(s['total_bills']) ?? 0,
          activeCount: Js.i(s['active_count']) ?? 0,
          cancelledCount: Js.i(s['cancelled_count']) ?? 0,
          cancelledAmount: Js.d(s['cancelled_amount']),
          avgBillAmount: Js.d(s['avg_bill_amount']),
          topCategory: Js.s(s['top_category'], 'None'),
        ),
        items: Js.mapList(d['items']).map(ExpenseMappers.expense).toList(),
        byCategory: Js.mapList(d['by_category'])
            .map((c) => ExpenseReportBucket(
                  name: Js.s(c['categoryName']),
                  color: Color(ApiMappers.colorFromServer(c['color'], 0xFF2563EB)),
                  amount: Js.d(c['activeAmount']),
                  billCount: Js.i(c['billCount']) ?? 0,
                  percent: Js.d(c['percent']),
                ))
            .toList(),
        companies: Js.mapList(lk['companies'])
            .map((c) => ExpenseLookupItem(Js.s(c['uid']), Js.s(c['company_name'])))
            .toList(),
        categories: Js.mapList(lk['categories'])
            .map((c) => ExpenseLookupItem(
                  Js.s(c['uid']),
                  Js.s(c['name']),
                  Color(ApiMappers.colorFromServer(c['color'], 0xFF2563EB)),
                ))
            .toList(),
        paymentModes: Js.strList(lk['payment_modes']),
        defaultFrom: Js.dt(dates['from_date']),
        defaultTo: Js.dt(dates['to_date']),
      );
    } catch (e, st) {
      _fail('Error fetching expense report', e, st);
    }
  }
}