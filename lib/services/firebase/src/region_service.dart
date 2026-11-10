import '/models/models.dart';
import '/services/api/api.dart';
import '/services/services.dart';

/// Countries / states / districts / cities from locations.php (read only; the
/// data comes from the server's india_locations.json). The server identifies
/// places by NAME, so [regionId] / [stateId] arguments are names.
class RegionService {
  static List<RegionModel>? _cachedCountries;

  static Future<List<dynamic>> _get(String type, [Map<String, dynamic>? q]) async {
    final res = (await ApiClient.instance.get(
      ApiEndpoints.locations,
      query: {'type': type, ...?q},
      auth: false,
    ))
        .ensureSuccess();
    return res.dataList;
  }

  static Future<List<RegionModel>> getCountries({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCountries != null) return _cachedCountries!;
    try {
      final rows = Js.mapList(await _get('countries'));
      _cachedCountries = rows
          .map((m) => RegionModel(
                uid: Js.s(m['name']),
                id: Js.i(m['id']) ?? 0,
                currencySymbol: Js.s(m['currencySymbol']),
                name: Js.s(m['name']),
                emoji: Js.s(m['emoji']),
              ))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return _cachedCountries!;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting countries: $e';
    }
  }

  /// [regionId] = country name.
  static Future<List<StateModel>> getStates({required String regionId}) async {
    try {
      final rows = Js.mapList(await _get('states', {'country': regionId}));
      return rows
          .map((m) => StateModel(
                uid: Js.s(m['name']),
                id: Js.i(m['id']) ?? 0,
                name: Js.s(m['name']),
                type: Js.s(m['type']),
              ))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting states: $e';
    }
  }

  static Future<List<DistrictModel>> getDistricts({
    required String regionId,
    required String stateId,
  }) async {
    final rows = Js.mapList(await _get('districts', {'country': regionId, 'state': stateId}));
    return rows
        .map((m) => DistrictModel(uid: Js.s(m['name']), id: Js.i(m['id']) ?? 0, name: Js.s(m['name'])))
        .toList();
  }

  /// [stateId] = state name; [districtId] = district name.
  static Future<List<CityModel>> getCities({
    required String regionId,
    required String stateId,
    String districtId = '',
  }) async {
    try {
      final rows = await _get('cities', {
        'country': regionId,
        'state': stateId,
        'district': districtId,
      });
      return rows.map((e) {
        final name = e is Map ? Js.s(e['name']) : e.toString();
        return CityModel(uid: name, id: e is Map ? (Js.i(e['id']) ?? 0) : 0, name: name);
      }).toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting cities: $e';
    }
  }
}
