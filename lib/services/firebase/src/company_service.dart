import '/models/models.dart';
import '/services/services.dart';

/// Legacy multi-company / kiosk module. The PHP API has no equivalent
/// endpoints (the "Our Companies" screens use MasterCompanyService +
/// master_companies.php instead), so this returns no data and write
/// operations report that they are unavailable. See MISSING_API_REQUIREMENTS.md.
class CompanyService {
  static const _na = 'This feature is not available on the server.';

  static Future<String?> createCompany({required CompanyModel company}) async => throw _na;

  static Future<void> updateCompany({
    required String uid,
    required CompanyModel company,
  }) async => throw _na;

  static Future<CompanyModel> getCompany({required String uid}) async => throw _na;

  static Future<List<CompanyModel>> getAllCompanies() async => <CompanyModel>[];

  static Future<void> deleteCompanyLogo({required String uid}) async => throw _na;

  static Future<void> deleteCompany({required String uid}) async => throw _na;

  static Future<void> saveGeofence({
    required String companyId,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) => CompanyLocationService.saveGeofence(
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
  );

  static Future<void> updateKioskSettings({
    required String companyId,
    required bool withoutLoginEnabled,
    required String notificationLanguage,
    String? kioskUsername,
  }) async => throw _na;

  static Future<bool> isKioskUsernameAvailable(
    String username,
    String? currentCompanyId,
  ) async => false;
}
