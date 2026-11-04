import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class ClientService {
  static final FirebaseConfig firebase = FirebaseConfig();

  /// Builds a normalized set of dedupe keys. Contacts are matched by
  /// email/mobile only (names repeat too often to be a reliable
  /// signal); companies are matched by office phone, GST/VAT number,
  /// and company name, so the two lists never cross-match.
  static List<String> duplicateKeysFor({
    String? email,
    String? mobile,
    String? name,
    String? gstVatNumber,
  }) {
    final normEmail = (email ?? '').trim().toLowerCase();
    final normMobile = (mobile ?? '').trim();
    final normName = (name ?? '').trim().toLowerCase();
    final normGst = (gstVatNumber ?? '').trim().toLowerCase();

    final keys = <String>[];
    if (normEmail.isNotEmpty) keys.add('email:$normEmail');
    if (normMobile.isNotEmpty) keys.add('mobile:$normMobile');
    if (normGst.isNotEmpty) keys.add('gst:$normGst');
    if (normName.isNotEmpty) keys.add('name:$normName');
    return keys;
  }

  static List<String> duplicateKeysForClient(ClientModel client) {
    if (client.isCompany) {
      // A Master Client is identified by company name / GST-VAT only. The
      // contact mobile and office phone can legitimately repeat.
      return duplicateKeysFor(
        name: client.companyName,
        gstVatNumber: client.gstVatNumber,
      );
    }
    // Contacts: many people share the same name, so only email and
    // mobile number identify a genuine duplicate — name is excluded.
    return duplicateKeysFor(
      email: client.email,
      mobile: client.mobileNumber,
    );
  }

  /// Returns true if [client] matches an existing client of the same
  /// type (company vs contact) by email, mobile/office phone, GST/VAT
  /// number, or name. Pass [excludeUid] when editing.
  static Future<bool> isDuplicateClient({
    required ClientModel client,
    List<ClientModel>? existingClients,
    String? excludeUid,
  }) async {
    final clients = existingClients ?? await getAllClients();
    final existingKeys = <String>{
      for (final c in clients)
        if (c.uid != excludeUid && c.isCompany == client.isCompany)
          ...duplicateKeysForClient(c),
    };
    final newKeys = duplicateKeysForClient(client);
    return newKeys.any(existingKeys.contains);
  }

  /// Returns the uid of an existing client of the same type (company vs
  /// contact) that matches [client] by the same keys used for duplicate
  /// detection, or null when there is no match.
  static Future<String?> findExistingClientId({
    required ClientModel client,
    List<ClientModel>? existingClients,
  }) async {
    final clients = existingClients ?? await getAllClients();
    final newKeys = duplicateKeysForClient(client).toSet();
    if (newKeys.isEmpty) return null;
    for (final c in clients) {
      if (c.uid == null || c.isCompany != client.isCompany) continue;
      if (duplicateKeysForClient(c).any(newKeys.contains)) return c.uid;
    }
    return null;
  }

  /// Reuses the matching existing client if there is one, otherwise
  /// creates a new one. Used when a deal is saved (e.g. after converting
  /// a lead) so an already-known company does not block the deal.
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
      if (!skipDuplicateCheck) {
        final isDuplicate = await isDuplicateClient(client: client);
        if (isDuplicate) {
          throw client.isCompany
              ? 'This client already exists (matching company name or GST/VAT number).'
              : 'This contact already exists (matching email or mobile number).';
        }
      }

      var cid = await Spdb.getCid();
      var name = client.isCompany
          ? (client.companyName ?? 'A new company')
          : (client.clientName ?? 'A new contact');
      var docRef = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.clients.name}',
        client.toMap(),
        activity: '$name has been added as a client',
      );

      return docRef.id;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      if (e is String &&
          (e.startsWith('This client already exists') ||
              e.startsWith('This company already exists') ||
              e.startsWith('This contact already exists'))) {
        rethrow;
      }
      throw 'Error creating client: $e';
    }
  }

  static Future<void> editClient({
    required String uid,
    required ClientModel client,
    bool skipDuplicateCheck = false,
  }) async {
    try {
      var cid = await Spdb.getCid();

      if (!skipDuplicateCheck) {
        final isDuplicate = await isDuplicateClient(
          client: client,
          excludeUid: uid,
        );
        if (isDuplicate) {
          throw client.isCompany
              ? 'This client already exists (matching company name or GST/VAT number).'
              : 'This contact already exists (matching email or mobile number).';
        }
      }

      var name = client.isCompany
          ? (client.companyName ?? 'Company')
          : (client.clientName ?? 'Contact');
      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.clients.name}',
        uid,
        client.toUpdateMap(),
        activity: '$name has been updated',
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      if (e is String &&
          (e.startsWith('This client already exists') ||
              e.startsWith('This company already exists') ||
              e.startsWith('This contact already exists'))) {
        rethrow;
      }
      throw 'Error updating client: $e';
    }
  }

  static Future<ClientModel> getClient({required String uid}) async {
    try {
      final cid = await Spdb.getCid();

      if (cid == null || cid.isEmpty) {
        throw 'Invalid company id';
      }

      if (uid.isEmpty) {
        throw 'Invalid client id';
      }

      final docRef = firebase.users
          .doc(cid)
          .collection(Collections.clients.name)
          .doc(uid);

      final clientDoc = await docRef.get();

      if (!clientDoc.exists) {
        throw 'Client not found';
      }

      final data = clientDoc.data();
      if (data == null) {
        throw 'Client data is empty';
      }

      return ClientModel.fromMap(clientDoc.id, data);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("getClient error: $e\n$st");
      throw 'Error loading client: $e';
    }
  }

  static Future<void> deleteClientProfileImage({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var client = await firebase.users
          .doc(cid)
          .collection(Collections.clients.name)
          .doc(uid)
          .get();
      var profilePictureUrl = client.data()?['profilePictureUrl'];
      if (profilePictureUrl != null) {
        await StorageService.deleteImage(profilePictureUrl);
      }

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.clients.name}',
        uid,
        {'profilePictureUrl': null},
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error deleting client: $e';
    }
  }

  static Future<void> deleteClientCompanyLogo({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var client = await firebase.users
          .doc(cid)
          .collection(Collections.clients.name)
          .doc(uid)
          .get();
      var companyLogoUrl = client.data()?['companyLogoUrl'];
      if (companyLogoUrl != null) {
        await StorageService.deleteImage(companyLogoUrl);
      }

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.clients.name}',
        uid,
        {'companyLogoUrl': null},
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error deleting client: $e';
    }
  }

  static Future<List<ClientModel>> getAllClients() async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.clients.name)
          .get();

      // debugPrint("Total Client Docs: ${querySnapshot.docs.length}");

      List<ClientModel> clients = querySnapshot.docs.map((doc) {
        // debugPrint("Client Data: ${doc.data()}");

        return ClientModel.fromMap(doc.id, doc.data());
      }).toList();

      // Remove null/empty names
      clients = clients.where((e) {
        if (e.isCompany) {
          return e.companyName != null && e.companyName!.trim().isNotEmpty;
        } else {
          return e.clientName != null && e.clientName!.trim().isNotEmpty;
        }
      }).toList();

      // Safe sort
      clients.sort((a, b) {
        final nameA = a.isCompany
            ? (a.companyName ?? '')
            : (a.clientName ?? '');
        final nameB = b.isCompany
            ? (b.companyName ?? '')
            : (b.clientName ?? '');
        return nameA.compareTo(nameB);
      });

      debugPrint(
        "Client Names: ${clients.map((e) => e.isCompany ? e.companyName : e.clientName).toList()}",
      );

      return clients;
    } catch (e, st) {
      await ErrorService.recordError(e, st);

      debugPrint("${e.toString()}, ${st.toString()}");

      throw 'Error fetching clients: $e';
    }
  }

  /// Master Clients only (a company and its contact saved together).
  static Future<List<ClientModel>> getMasterClients() async {
    final all = await getAllClients();
    return all
        .where((c) => c.isCompany && (c.companyName?.trim().isNotEmpty ?? false))
        .toList();
  }

  /// Leads count, deals count and total deal value per Master Client uid.
  static Future<Map<String, ({int leads, int deals, double value})>>
  getClientStats() async {
    try {
      final cid = await Spdb.getCid();
      final leadsSnap = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .get();
      final dealsSnap = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .get();

      final leads = <String, int>{};
      final deals = <String, int>{};
      final values = <String, double>{};

      for (final d in leadsSnap.docs) {
        final id = d.data()['clientId'];
        if (id is String && id.isNotEmpty) leads[id] = (leads[id] ?? 0) + 1;
      }
      for (final d in dealsSnap.docs) {
        final data = d.data();
        final id = data['clientId'];
        if (id is! String || id.isEmpty) continue;
        deals[id] = (deals[id] ?? 0) + 1;
        final v = data['dealValue'];
        final value = v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
        values[id] = (values[id] ?? 0) + value;
      }

      final ids = {...leads.keys, ...deals.keys};
      return {
        for (final id in ids)
          id: (
            leads: leads[id] ?? 0,
            deals: deals[id] ?? 0,
            value: values[id] ?? 0.0,
          ),
      };
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return {};
    }
  }

  static Future<bool> isClientAssigned(String clientUid) async {
    try {
      var cid = await Spdb.getCid();

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .where('clientId', isEqualTo: clientUid)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return true;

      final deals = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .where('clientId', isEqualTo: clientUid)
          .limit(1)
          .get();

      return deals.docs.isNotEmpty;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking client assignment: $e\n$st");
      return false;
    }
  }

  static Future<void> deleteClient({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.clients.name)
          .doc(uid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;

      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      await docRef.reference.delete();

      var isCompany = data['isCompany'] ?? false;
      var name = isCompany
          ? (data['companyName'] ?? 'Company')
          : (data['clientName'] ?? 'Contact');

      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '$name has been deleted',
        description: 'User has deleted an entry in ${Collections.clients.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.clients.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting client: $e\n$st");
      throw 'Error deleting client: $e';
    }
  }

  static Future<void> restoreClient(ClientModel client) async {
    var cid = await Spdb.getCid();

    final uid = client.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.clients.name)
        .doc(uid)
        .set(client.toMap());
  }
}