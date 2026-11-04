import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';

class RegionService {
  static final FirebaseConfig firebase = FirebaseConfig();
  static List<RegionModel>? _cachedCountries;
  static final List<Map<String, dynamic>> countriesData = [
    {
      "id": 1,
      "name": "India",
      "code": "IN",
      "dial_code": "+91",
      "currency_symbol": "₹",
      "emoji": "🇮🇳",
      "states": [
        {
          "id": 1,
          "name": "Tamil Nadu",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Chennai"},
            {"id": 2, "name": "Madurai"},
            {"id": 3, "name": "Coimbatore"},
            {"id": 4, "name": "Salem"},
            {"id": 5, "name": "Sivakasi"},
            {"id": 6, "name": "Sattur"},
            {"id": 7, "name": "Rajapalayam"},
          ],
        },
        {
          "id": 2,
          "name": "Karnataka",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Bangalore"},
            {"id": 2, "name": "Mysore"},
            {"id": 3, "name": "Mangalore"},
            {"id": 4, "name": "Hubli"},
          ],
        },
        {
          "id": 3,
          "name": "Maharashtra",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Mumbai"},
            {"id": 2, "name": "Pune"},
            {"id": 3, "name": "Nagpur"},
            {"id": 4, "name": "Nashik"},
          ],
        },
        {
          "id": 4,
          "name": "Kerala",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Kochi"},
            {"id": 2, "name": "Thiruvananthapuram"},
            {"id": 3, "name": "Kozhikode"},
          ],
        },
        {
          "id": 5,
          "name": "Andhra Pradesh",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Visakhapatnam"},
            {"id": 2, "name": "Vijayawada"},
            {"id": 3, "name": "Guntur"},
          ],
        },
        {
          "id": 6,
          "name": "Telangana",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Hyderabad"},
            {"id": 2, "name": "Warangal"},
          ],
        },
        {
          "id": 7,
          "name": "Gujarat",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Ahmedabad"},
            {"id": 2, "name": "Surat"},
            {"id": 3, "name": "Vadodara"},
          ],
        },
        {
          "id": 8,
          "name": "Rajasthan",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Jaipur"},
            {"id": 2, "name": "Udaipur"},
            {"id": 3, "name": "Jodhpur"},
          ],
        },
        {
          "id": 9,
          "name": "Uttar Pradesh",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Lucknow"},
            {"id": 2, "name": "Kanpur"},
            {"id": 3, "name": "Varanasi"},
          ],
        },
        {
          "id": 10,
          "name": "Madhya Pradesh",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Bhopal"},
            {"id": 2, "name": "Indore"},
            {"id": 3, "name": "Gwalior"},
          ],
        },
        {
          "id": 11,
          "name": "West Bengal",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Kolkata"},
            {"id": 2, "name": "Howrah"},
            {"id": 3, "name": "Durgapur"},
          ],
        },
        {
          "id": 12,
          "name": "Punjab",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Amritsar"},
            {"id": 2, "name": "Ludhiana"},
            {"id": 3, "name": "Chandigarh"},
          ],
        },
        {
          "id": 13,
          "name": "Haryana",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Gurgaon"},
            {"id": 2, "name": "Faridabad"},
          ],
        },
        {
          "id": 14,
          "name": "Bihar",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Patna"},
            {"id": 2, "name": "Gaya"},
          ],
        },
        {
          "id": 15,
          "name": "Odisha",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Bhubaneswar"},
            {"id": 2, "name": "Cuttack"},
          ],
        },
        {
          "id": 16,
          "name": "Assam",
          "type": "State",
          "cities": [
            {"id": 1, "name": "Guwahati"},
            {"id": 2, "name": "Silchar"},
          ],
        },
        {
          "id": 30,
          "name": "Delhi",
          "type": "Union Territory",
          "cities": [
            {"id": 1, "name": "New Delhi"},
          ],
        },
        {
          "id": 31,
          "name": "Puducherry",
          "type": "Union Territory",
          "cities": [
            {"id": 1, "name": "Puducherry"},
          ],
        },
        {
          "id": 32,
          "name": "Jammu and Kashmir",
          "type": "Union Territory",
          "cities": [
            {"id": 1, "name": "Srinagar"},
            {"id": 2, "name": "Jammu"},
          ],
        },
        {
          "id": 33,
          "name": "Ladakh",
          "type": "Union Territory",
          "cities": [
            {"id": 1, "name": "Leh"},
          ],
        },
      ],
    },
  ];

  static Future<void> seedRegions() async {
    final firestore = FirebaseFirestore.instance;

    for (var country in countriesData) {
      // 👉 Create Country
      final countryRef = firestore.collection('regions').doc();

      await countryRef.set({
        "id": country['id'],
        "name": country['name'],
        "code": country['code'],
        "dial_code": country['dial_code'],
        "currency_symbol": country['currency_symbol'],
        "emoji": country['emoji'],
      });

      // 👉 States
      List states = country['states'] ?? [];

      for (var state in states) {
        final stateRef = countryRef.collection('states').doc();

        await stateRef.set({
          "id": state['id'],
          "name": state['name'],
          "type": state['type'],
        });

        // 👉 Cities
        List cities = state['cities'] ?? [];

        for (var city in cities) {
          final cityRef = stateRef.collection('cities').doc();

          await cityRef.set({"id": city['id'], "name": city['name']});
        }
      }
    }

    debugPrint("✅ Full Region Data Seeded Successfully");
  }

  static Future<List<RegionModel>> getCountries({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedCountries != null) return _cachedCountries!;

    final snapshot = await firebase.regions.orderBy('name').get();

    // If regions collection is empty, seed it with default data
    if (snapshot.docs.isEmpty) {
      await seedRegions();
      // Fetch again after seeding
      final seededSnapshot = await firebase.regions.orderBy('name').get();
      _cachedCountries = seededSnapshot.docs
          .map((d) => RegionModel.fromMap({...d.data(), 'uid': d.id}))
          .toList();
    } else {
      _cachedCountries = snapshot.docs
          .map((d) => RegionModel.fromMap({...d.data(), 'uid': d.id}))
          .toList();
    }

    return _cachedCountries!;
  }

  static Future<List<StateModel>> getStates({required String regionId}) async {
    try {
      List<StateModel> countries = [];
      var stateDocs = await firebase.regions
          .doc(regionId)
          .collection('states')
          .orderBy('name')
          .get();

      for (var i in stateDocs.docs) {
        var data = i.data();
        data['uid'] = i.id;
        countries.add(StateModel.fromMap(data));
      }

      return countries;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error getting states: $e';
    }
  }

  static Future<List<CityModel>> getCities({
    required String regionId,
    required String stateId,
  }) async {
    try {
      List<CityModel> countries = [];
      var citiesDocs = await firebase.regions
          .doc(regionId)
          .collection('states')
          .doc(stateId)
          .collection('cities')
          .orderBy('name')
          .get();

      for (var i in citiesDocs.docs) {
        var data = i.data();
        data['uid'] = i.id;
        countries.add(CityModel.fromMap(data));
      }

      return countries;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error getting cities: $e';
    }
  }
}
