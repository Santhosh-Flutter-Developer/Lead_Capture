import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class CompanyService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<String?> createCompany({required CompanyModel company}) async {
    try {
      var cid = await Spdb.getCid();
      var docRef = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.companies.name}',
        company.toMap(),
        activity: '${company.name} has been added as a company',
      );

      return docRef.id;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error creating company: $e';
    }
  }

  static Future<void> updateCompany({
    required String uid,
    required CompanyModel company,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.companies.name}',
        uid,
        company.toUpdateMap(),
        activity: '${company.name} has been updated',
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error updating company: $e';
    }
  }

  static Future<CompanyModel> getCompany({required String uid}) async {
    try {
      final cid = await Spdb.getCid();

      if (cid == null || cid.isEmpty) {
        throw 'Invalid company id';
      }

      if (uid.isEmpty) {
        throw 'Invalid company id';
      }

      final docRef = firebase.users
          .doc(cid)
          .collection(Collections.companies.name)
          .doc(uid);

      final companyDoc = await docRef.get();

      if (!companyDoc.exists) {
        throw 'Company not found';
      }

      final data = companyDoc.data();
      if (data == null) {
        throw 'Company data is empty';
      }

      return CompanyModel.fromMap(companyDoc.id, data);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("getCompany error: $e\n$st");
      throw 'Error loading company: $e';
    }
  }

  static Future<List<CompanyModel>> getAllCompanies() async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.companies.name)
          .get();

      debugPrint("Total Company Docs: ${querySnapshot.docs.length}");

      List<CompanyModel> companies = querySnapshot.docs.map((doc) {
        return CompanyModel.fromMap(doc.id, doc.data());
      }).toList();

      // Sort by name
      companies.sort((a, b) => a.name.compareTo(b.name));

      return companies;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching companies: $e';
    }
  }

  static Future<void> deleteCompanyLogo({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var company = await firebase.users
          .doc(cid)
          .collection(Collections.companies.name)
          .doc(uid)
          .get();
      var logoUrl = company.data()?['logoUrl'];
      if (logoUrl != null) {
        await StorageService.deleteImage(logoUrl);
      }

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.companies.name}',
        uid,
        {'logoUrl': null},
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error deleting company logo: $e';
    }
  }

  static Future<void> deleteCompany({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.companies.name)
          .doc(uid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;

      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      await docRef.reference.delete();

      var name = data['name'] != null ? data['name'] as String : 'Company';

      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '$name has been deleted',
        description: 'User has deleted an entry in ${Collections.companies.name}',
        collection: '${Collections.users.name}/$cid/${Collections.companies.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting company: $e\n$st");
      throw 'Error deleting company: $e';
    }
  }

  static Future<void> saveGeofence({
    required String companyId,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    try {
      var cid = await Spdb.getCid();
      await firebase.users
          .doc(cid)
          .collection(Collections.companies.name)
          .doc(companyId)
          .update({
        'latitude': latitude,
        'longitude': longitude,
        'radius': radiusMeters.toInt(),
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error saving geofence: $e\n$st");
      throw 'Error saving geofence: $e';
    }
  }

  static Future<void> updateKioskSettings({
    required String companyId,
    required bool withoutLoginEnabled,
    required String notificationLanguage,
    String? kioskUsername,
  }) async {
    try {
      var cid = await Spdb.getCid();
      await firebase.users
          .doc(cid)
          .collection(Collections.companies.name)
          .doc(companyId)
          .update({
        'withoutLoginEnabled': withoutLoginEnabled,
        'notificationLanguage': notificationLanguage,
        'kioskUsername': kioskUsername,
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error updating kiosk settings: $e\n$st");
      throw 'Error updating kiosk settings: $e';
    }
  }

  static Future<bool> isKioskUsernameAvailable(
    String username,
    String currentCompanyId,
  ) async {
    try {
      final cid = await Spdb.getCid();
      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.companies.name)
          .where('kioskUsername', isEqualTo: username)
          .get();

      if (snapshot.docs.isEmpty) return true;

      // If the username exists, check if it's the same company
      for (var doc in snapshot.docs) {
        if (doc.id == currentCompanyId) return true;
      }

      return false;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return false;
    }
  }
}
