import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Master Clients – backed by master_clients.php (no Firestore).
/// The server only stores company-type clients (company + contact), so the
/// separate "individual contact" client type of the Firestore version is not
/// available; contact-only fields (gender, salutation, photo, login) are not
/// persisted.
class ClientService {
  static List<String> duplicateKeysFor({
    String? email,
    String? mobile,
    String? companyName,
    String? gst,
    bool isCompany = true,
  }) => <String>[
    if ((companyName ?? '').trim().isNotEmpty) 'company:${companyName!.trim().toLowerCase()}',
    if ((mobile ?? '').trim().isNotEmpty) 'mobile:${mobile!.trim()}',
    if ((gst ?? '').trim().isNotEmpty) 'gst:${gst!.trim().toLowerCase()}',
  ];

  static List<String> duplicateKeysForClient(ClientModel c) => duplicateKeysFor(
    companyName: c.companyName,
    mobile: c.mobileNumber,
    gst: c.gstVatNumber,
  );

  static Never _fail(String prefix, Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$prefix: $e\n$st');
    if (e is ApiException) throw e.message;
    if (e is String) throw e;
    throw '$prefix: $e';
  }

  static Map<String, dynamic> _body(ClientModel m) => {
    'company_name': m.companyName ?? '',
    'contact_name': m.clientName ?? '',
    'mobile_number': m.mobileNumber ?? '',
    'email': m.email ?? '',
    'gst_vat_number': m.gstVatNumber ?? '',
    'country': m.country?.name ?? 'India',
    'state': m.state?.name,
    'district': m.district?.name,
    'city': m.city?.name,
    'postal_code': m.postalCode ?? '',
    'company_address': m.companyAddress ?? '',
    'office_phone_no': m.officePhoneNo ?? '',
    'shipping_address': m.shippingAddress ?? '',
    'notes': m.notes ?? '',
  };

  /// Server-side duplicate check (company name / mobile / GST).
  static Future<bool> isDuplicateClient({
    required ClientModel client,
    List<ClientModel>? existingClients,
    String? excludeUid,
  }) async {
    try {
      final res = (await MasterClientsApiService.call('check_duplicate', {
        'company_name': client.companyName ?? '',
        'mobile_number': client.mobileNumber ?? '',
        'gst_vat_number': client.gstVatNumber ?? '',
        'exclude_uid': excludeUid ?? '',
      })).ensureSuccess();
      return Js.b(res.dataMap['is_duplicate']);
    } catch (e, st) {
      _fail('Error checking duplicate', e, st);
    }
  }

  static Future<String?> findExistingClientId({
    required ClientModel client,
    List<ClientModel>? existingClients,
  }) async {
    final res = (await MasterClientsApiService.call('check_duplicate', {
      'company_name': client.companyName ?? '',
      'mobile_number': client.mobileNumber ?? '',
      'gst_vat_number': client.gstVatNumber ?? '',
    })).ensureSuccess();
    final ex = Js.m(res.dataMap['existing']);
    return ex.isEmpty ? null : Js.s(ex['uid']);
  }

  static Future<String?> getOrCreateClient({required ClientModel client}) async {
    final existingId = await findExistingClientId(client: client);
    if (existingId != null) return existingId;
    return createClient(client: client, skipDuplicateCheck: true);
  }

  static Future<String?> createClient({
    required ClientModel client,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      final res = (await MasterClientsApiService.call('create', _body(client))).ensureSuccess();
      ApiLive.changed('master_clients');
      return Js.opt(res.dataMap['uid']);
    } catch (e, st) {
      _fail('Error creating client', e, st);
    }
  }

  static Future<void> editClient({
    required String uid,
    required ClientModel client,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      (await MasterClientsApiService.call('update', {'uid': uid, ..._body(client)})).ensureSuccess();
      ApiLive.changed('master_clients');
    } catch (e, st) {
      _fail('Error updating client', e, st);
    }
  }

  static Future<ClientModel> getClient({required String uid}) async {
    try {
      final res = (await MasterClientsApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.client(res.dataMap);
    } catch (e, st) {
      _fail('Error getting client', e, st);
    }
  }

  /// Master clients carry no profile photo / company logo on the server.
  static Future<void> deleteClientProfileImage({required String uid}) async {}
  static Future<void> deleteClientCompanyLogo({required String uid}) async {}

  static List<Map<String, dynamic>>? _cache;

  static Future<List<Map<String, dynamic>>> _rows() async {
    final res = (await MasterClientsApiService.call('list')).ensureSuccess();
    return _cache = res.dataList.map(Js.m).toList();
  }

  static Future<List<ClientModel>> getAllClients() async {
    try {
      final list = (await _rows()).map(CrmMappers.client).toList();
      list.removeWhere((c) => (c.companyName ?? '').trim().isEmpty);
      list.sort((a, b) => (a.companyName ?? '').compareTo(b.companyName ?? ''));
      return list;
    } catch (e, st) {
      _fail('Error fetching clients', e, st);
    }
  }

  static Future<List<ClientModel>> getMasterClients() => getAllClients();

  /// Leads count, deals count and total deal value per client (from list).
  static Future<Map<String, ({int leads, int deals, double value})>> getClientStats() async {
    try {
      final rows = _cache ?? await _rows();
      return {
        for (final r in rows)
          Js.s(r['uid']): (
            leads: Js.i(r['leads_count']) ?? 0,
            deals: Js.i(r['deals_count']) ?? 0,
            value: Js.d(r['total_deal_value']),
          ),
      };
    } catch (e, st) {
      _fail('Error getting client stats', e, st);
    }
  }

  /// The server refuses (with a reason) when leads/deals/projects/tickets exist.
  static Future<bool> isClientAssigned(String clientUid) async => false;

  static Future<void> deleteClient({required String uid}) async {
    try {
      (await MasterClientsApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'master_clients', 'trash'});
    } catch (e, st) {
      _fail('Error deleting client', e, st);
    }
  }

  static Future<void> restoreClient(ClientModel client) async {
    try {
      (await MasterClientsApiService.call('restore', {'uid': client.uid})).ensureSuccess();
      ApiLive.changed({'master_clients', 'trash'});
    } catch (e, st) {
      _fail('Error restoring client', e, st);
    }
  }
}
