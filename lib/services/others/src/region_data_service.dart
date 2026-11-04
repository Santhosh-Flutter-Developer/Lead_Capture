import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '/models/models.dart';

/// Offline Country -> State -> District -> City data, bundled in
/// `assets/data/india_locations.json`.
///
/// Every list is derived from the previous selection, so callers just pass the
/// chosen names down the chain:
///
/// ```dart
/// final states = await RegionDataService.getStates(country: 'India');
/// final districts = await RegionDataService.getDistricts(
///   country: 'India', state: 'Tamil Nadu');
/// final cities = await RegionDataService.getCities(
///   country: 'India', state: 'Tamil Nadu', district: 'Madurai');
/// ```
///
/// To support another country, add one more entry to the `countries` array of
/// the JSON asset with the same `states -> districts -> cities` shape.
class RegionDataService {
  static const String _asset = 'assets/data/india_locations.json';
  static const String defaultCountryName = 'India';

  static List<Map<String, dynamic>>? _raw;

  static Future<List<Map<String, dynamic>>> _load() async {
    if (_raw != null) return _raw!;
    final text = await rootBundle.loadString(_asset);
    final decoded = json.decode(text) as Map<String, dynamic>;
    _raw = (decoded['countries'] as List).cast<Map<String, dynamic>>();
    return _raw!;
  }

  static Map<String, dynamic>? _find(List list, String? name) {
    if (name == null) return null;
    for (final e in list) {
      if ((e as Map)['name'] == name) return e.cast<String, dynamic>();
    }
    return null;
  }

  static Future<List<RegionModel>> getCountries() async {
    final data = await _load();
    return [
      for (final c in data)
        RegionModel(
          id: c['id'] as int,
          currencySymbol: (c['currencySymbol'] ?? '') as String,
          name: c['name'] as String,
          emoji: (c['emoji'] ?? '') as String,
        ),
    ];
  }

  /// The country that is pre-selected on new forms (India).
  static Future<RegionModel?> getDefaultCountry() async {
    final countries = await getCountries();
    for (final c in countries) {
      if (c.name == defaultCountryName) return c;
    }
    return countries.isEmpty ? null : countries.first;
  }

  static Future<List<StateModel>> getStates({required String? country}) async {
    final c = _find(await _load(), country);
    if (c == null) return [];
    return [
      for (final s in (c['states'] as List).cast<Map<String, dynamic>>())
        StateModel(
          id: s['id'] as int,
          name: s['name'] as String,
          type: (s['type'] ?? 'State') as String,
        ),
    ];
  }

  static Future<List<DistrictModel>> getDistricts({
    required String? country,
    required String? state,
  }) async {
    final c = _find(await _load(), country);
    final s = c == null ? null : _find(c['states'] as List, state);
    if (s == null) return [];
    return [
      for (final d in (s['districts'] as List).cast<Map<String, dynamic>>())
        DistrictModel(id: d['id'] as int, name: d['name'] as String),
    ];
  }

  static Future<List<CityModel>> getCities({
    required String? country,
    required String? state,
    required String? district,
  }) async {
    final c = _find(await _load(), country);
    final s = c == null ? null : _find(c['states'] as List, state);
    final d = s == null ? null : _find(s['districts'] as List, district);
    if (d == null) return [];
    final cities = (d['cities'] as List).cast<String>();
    return [
      for (var i = 0; i < cities.length; i++)
        CityModel(id: i + 1, name: cities[i]),
    ];
  }
}