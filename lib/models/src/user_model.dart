/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// ignore_for_file: public_member_api_docs, sort_constructors_first

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:leadcapture/models/src/device_model.dart';

// Project imports:
import '/constants/constants.dart';

class UserModel {
  String uid;
  String name;
  String mobileNumber;
  String? img;
  String collectionId;
  UserType type;
  String userName;
  String password;
  List<String>? accessPages;
  String? fcmId;
  DeviceModel device;
  DateTime created;
  DateTime modified;
  UserModel({
    required this.uid,
    required this.name,
    required this.mobileNumber,
    this.img,
    required this.collectionId,
    required this.type,
    required this.userName,
    required this.password,
    this.accessPages,
    this.fcmId,
    required this.device,
    required this.created,
    required this.modified,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? mobileNumber,
    String? img,
    String? collectionId,
    UserType? type,
    String? userName,
    String? password,
    List<String>? accessPages,
    String? fcmId,
    DeviceModel? device,
    DateTime? created,
    DateTime? modified,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      img: img ?? this.img,
      collectionId: collectionId ?? this.collectionId,
      type: type ?? this.type,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      accessPages: accessPages ?? this.accessPages,
      fcmId: fcmId ?? this.fcmId,
      device: device ?? this.device,
      created: created ?? this.created,
      modified: modified ?? this.modified,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, mobileNumber: $mobileNumber, img: $img, collectionId: $collectionId, type: $type, userName: $userName, password: $password, accessPages: $accessPages, fcmId: $fcmId, device: $device, created: $created, modified: $modified)';
  }

  @override
  bool operator ==(covariant UserModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.mobileNumber == mobileNumber &&
        other.img == img &&
        other.collectionId == collectionId &&
        other.type == type &&
        other.userName == userName &&
        other.password == password &&
        listEquals(other.accessPages, accessPages) &&
        other.fcmId == fcmId &&
        other.device == device &&
        other.created == created &&
        other.modified == modified;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        mobileNumber.hashCode ^
        img.hashCode ^
        collectionId.hashCode ^
        type.hashCode ^
        userName.hashCode ^
        password.hashCode ^
        accessPages.hashCode ^
        fcmId.hashCode ^
        device.hashCode ^
        created.hashCode ^
        modified.hashCode;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'mobileNumber': mobileNumber,
      'img': img,
      'device': device.toMap(),
      'type': type.name,
      'userName': userName,
      'password': password,
      'accessPages': accessPages,
      'fcmId': fcmId,
      'created': created.millisecondsSinceEpoch,
      'modified': modified.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'name': name,
      'mobileNumber': mobileNumber,
      'img': img,
      'userName': userName,
      'password': password,
      'type': type.name,
      'accessPages': accessPages,
      'modified': created.millisecondsSinceEpoch,
    };
  }
}
