/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// Package imports:

// Package imports:
import 'package:leadcapture/models/src/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import '/constants/constants.dart';

class Db {
  Db._internal();

  static final Db _instance = Db._internal();

  factory Db() {
    return _instance;
  }

  static Future<SharedPreferences> connect() async {
    return await SharedPreferences.getInstance();
  }

  static Future<bool> checkLogin() async {
    var cn = await connect();
    bool? r = cn.getBool('login');
    return r ?? false;
  }

  static Future setLogin({required UserModel model}) async {
    var cn = await connect();
    cn.setString('uid', model.uid);
    cn.setString('img', model.img ?? '');
    cn.setString('name', model.name);
    cn.setString('mobileNumber', model.mobileNumber);
    cn.setString('collectionId', model.collectionId);
    cn.setString('userType', model.type.name);
    cn.setStringList('accessPages', model.accessPages ?? []);
    cn.setBool('login', true);
    cn.setBool('minStockNotification', true);
    cn.setString('theme', 'light');
  }

  static Future<String?> getData({required UserData type}) async {
    var cn = await connect();
    if (type == UserData.name) {
      return cn.getString('name');
    } else if (type == UserData.uid) {
      return cn.getString('uid');
    } else if (type == UserData.img) {
      return cn.getString('img');
    } else if (type == UserData.mobileNumber) {
      return cn.getString('mobileNumber');
    } else if (type == UserData.collectionId) {
      return cn.getString('collectionId');
    } else if (type == UserData.type) {
      return cn.getString('userType');
    }
    return null;
  }

  static Future updateData(
      {required UserData type, required String value}) async {
    var cn = await connect();
    if (type == UserData.name) {
      return cn.setString('name', value);
    } else if (type == UserData.img) {
      return cn.setString('img', value);
    } else if (type == UserData.mobileNumber) {
      return cn.setString('mobileNumber', value);
    }
  }

  static Future<List<String>?> getAccessPages() async {
    var cn = await connect();
    return cn.getStringList('accessPages');
  }

  static Future<String?> getTheme() async {
    var cn = await connect();
    return cn.getString('theme');
  }

  static Future setTheme(theme) async {
    var cn = await connect();
    return cn.setString('theme', theme);
  }

  static Future<String?> getLocale() async {
    var cn = await connect();
    return cn.getString('locale');
  }

  static Future setLocale(locale) async {
    var cn = await connect();
    return cn.setString('locale', locale);
  }

  static Future<bool> clearDb() async {
    var cn = await connect();
    return cn.clear();
  }

  static Future setClockIn(String id) async {
    var cn = await connect();
    return cn.setString('clockIn', id);
  }

  static Future<String?> getClockIn() async {
    var cn = await connect();
    return cn.getString('clockIn');
  }

  static Future clearClockIn() async {
    var cn = await connect();
    return cn.remove('clockIn');
  }

  static Future setRide(String id) async {
    var cn = await connect();
    return cn.setString('ride', id);
  }

  static Future<String?> getRide() async {
    var cn = await connect();
    return cn.getString('ride');
  }

  static Future clearRide() async {
    var cn = await connect();
    return cn.remove('ride');
  }
}
