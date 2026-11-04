// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class DeviceModel {
  final String? deviceId;
  final String? deviceName;
  final String? brand;
  final String? model;
  final String? platform;
  final DateTime? lastLoginAt;
  final String? fcmId;
  DeviceModel({
    this.deviceId,
    this.deviceName,
    this.brand,
    this.model,
    this.platform,
    this.lastLoginAt,
    this.fcmId,
  });

  DeviceModel copyWith({
    String? deviceId,
    String? deviceName,
    String? brand,
    String? model,
    String? platform,
    DateTime? lastLoginAt,
    String? fcmId,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      platform: platform ?? this.platform,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      fcmId: fcmId ?? this.fcmId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'brand': brand,
      'model': model,
      'platform': platform,
      'lastLoginAt': lastLoginAt?.millisecondsSinceEpoch,
      'fcmId': fcmId,
    };
  }

  Map<String, dynamic> toMatchMap() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'brand': brand,
      'model': model,
      'platform': platform,
    };
  }

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    return DeviceModel(
      deviceId: map['deviceId'] != null && map['deviceId'] is String
          ? map['deviceId'] as String
          : null,
      deviceName: map['deviceName'] != null && map['deviceName'] is String
          ? map['deviceName'] as String
          : null,
      brand: map['brand'] != null && map['brand'] is String
          ? map['brand'] as String
          : null,
      model: map['model'] != null && map['model'] is String
          ? map['model'] as String
          : null,
      platform: map['platform'] != null && map['platform'] is String
          ? map['platform'] as String
          : null,
      lastLoginAt: map['lastLoginAt'] != null && map['lastLoginAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['lastLoginAt'] as int)
          : null,
      fcmId: map['fcmId'] != null && map['fcmId'] is String
          ? map['fcmId'] as String
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory DeviceModel.fromJson(String source) =>
      DeviceModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'DeviceModel(deviceId: $deviceId, deviceName: $deviceName, brand: $brand, model: $model, platform: $platform, lastLoginAt: $lastLoginAt, fcmId: $fcmId)';
  }

  @override
  bool operator ==(covariant DeviceModel other) {
    if (identical(this, other)) return true;

    return other.deviceId == deviceId &&
        other.deviceName == deviceName &&
        other.brand == brand &&
        other.model == model &&
        other.platform == platform &&
        other.lastLoginAt == lastLoginAt &&
        other.fcmId == fcmId;
  }

  @override
  int get hashCode {
    return deviceId.hashCode ^
        deviceName.hashCode ^
        brand.hashCode ^
        model.hashCode ^
        platform.hashCode ^
        lastLoginAt.hashCode ^
        fcmId.hashCode;
  }
}

class LoginAlertModel {
  String ipAddress;
  String location;
  DateTime dateTime;
  String device;
  LoginAlertModel({
    required this.ipAddress,
    required this.location,
    required this.dateTime,
    required this.device,
  });

  LoginAlertModel copyWith({
    String? ipAddress,
    String? location,
    DateTime? dateTime,
    String? device,
  }) {
    return LoginAlertModel(
      ipAddress: ipAddress ?? this.ipAddress,
      location: location ?? this.location,
      dateTime: dateTime ?? this.dateTime,
      device: device ?? this.device,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ipAddress': ipAddress,
      'location': location,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'device': device,
    };
  }

  factory LoginAlertModel.fromMap(Map<String, dynamic> map) {
    return LoginAlertModel(
      ipAddress: map['ipAddress'] as String,
      location: map['location'] as String,
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime'] as int),
      device: map['device'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory LoginAlertModel.fromJson(String source) =>
      LoginAlertModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'LoginAlertModel(ipAddress: $ipAddress, location: $location, dateTime: $dateTime, device: $device)';
  }

  @override
  bool operator ==(covariant LoginAlertModel other) {
    if (identical(this, other)) return true;

    return other.ipAddress == ipAddress &&
        other.location == location &&
        other.dateTime == dateTime &&
        other.device == device;
  }

  @override
  int get hashCode {
    return ipAddress.hashCode ^
        location.hashCode ^
        dateTime.hashCode ^
        device.hashCode;
  }
}
