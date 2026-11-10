import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';

/// "Our Companies" – backed by master_companies.php (no Firestore).
class MasterCompanyService {
  static Never _fail(String prefix, Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$prefix: $e\n$st');
    if (e is ApiException) throw e.message;
    if (e is String) throw e;
    throw '$prefix: $e';
  }

  static Map<String, dynamic> _body(MasterCompanyModel m) => {
    'company_name': m.companyName,
    'contact_name': m.contactName,
    'mobile_number': m.mobileNumber,
    'email': m.email ?? '',
    'gst_vat_number': m.gstVatNumber ?? '',
    'country': m.country?.name ?? 'India',
    'state': m.state?.name,
    'district': m.district?.name,
    'city': m.city?.name,
    'postal_code': m.postalCode ?? '',
    'company_address': m.companyAddress ?? '',
    'logo_url': ApiConfig.toRelativePath(m.logoUrl ?? ''),
  };

  static Future<List<MasterCompanyModel>> getAll() async {
    try {
      final res = (await MasterClientsApiService.companies('list')).ensureSuccess();
      return res.dataList.map((r) => CrmMappers.masterCompany(Js.m(r))).toList();
    } catch (e, st) {
      _fail('Error fetching companies', e, st);
    }
  }

  static Future<MasterCompanyModel> get({required String uid}) async {
    try {
      final res = (await MasterClientsApiService.companies('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.masterCompany(res.dataMap);
    } catch (e, st) {
      _fail('Error getting company', e, st);
    }
  }

  /// Duplicates are rejected by the server on create/update.
  static Future<bool> isDuplicate({
    required MasterCompanyModel company,
    String? excludeUid,
  }) async => false;

  static Future<String> create({required MasterCompanyModel company}) async {
    try {
      final res = (await MasterClientsApiService.companies('create', _body(company))).ensureSuccess();
      ApiLive.changed('master_companies');
      return Js.s(res.dataMap['uid']);
    } catch (e, st) {
      _fail('Error creating company', e, st);
    }
  }

  static Future<void> edit({
    required String uid,
    required MasterCompanyModel company,
  }) async {
    try {
      (await MasterClientsApiService.companies('update', {'uid': uid, ..._body(company)})).ensureSuccess();
      ApiLive.changed('master_companies');
    } catch (e, st) {
      _fail('Error updating company', e, st);
    }
  }

  static Future<void> delete({required String uid}) async {
    try {
      (await MasterClientsApiService.companies('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'master_companies', 'trash'});
    } catch (e, st) {
      _fail('Error deleting company', e, st);
    }
  }

  /// master_companies.php has no restore action.
  static Future<void> restore(MasterCompanyModel company) async {
    throw 'Restoring a deleted company is not supported by the server yet.';
  }
}
