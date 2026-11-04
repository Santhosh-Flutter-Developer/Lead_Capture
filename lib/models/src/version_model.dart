// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class VersionModel {
  String? version;
  String? platform;
  String? url;
  String? description;
  DateTime timestamp;
  bool isUpdateNeed;
  VersionModel({
    this.version,
    this.platform,
    this.url,
    this.description,
    required this.timestamp,
    this.isUpdateNeed = false,
  });

  VersionModel copyWith({
    String? version,
    String? platform,
    String? url,
    String? description,
    DateTime? timestamp,
    bool? isUpdateNeed,
  }) {
    return VersionModel(
      version: version ?? this.version,
      platform: platform ?? this.platform,
      url: url ?? this.url,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      isUpdateNeed: isUpdateNeed ?? this.isUpdateNeed,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'version': version,
      'platform': platform,
      'url': url,
      'description': description,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isUpdateNeed': isUpdateNeed,
    };
  }

  factory VersionModel.fromMap(Map<String, dynamic> map) {
    return VersionModel(
      version: map['version'] != null ? map['version'] as String : null,
      platform: map['platform'] != null ? map['platform'] as String : null,
      url: map['url'] != null ? map['url'] as String : null,
      description: map['description'] != null
          ? map['description'] as String
          : null,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isUpdateNeed: map['isUpdateNeed'] != null
          ? map['isUpdateNeed'] as bool
          : false,
    );
  }

  String toJson() => json.encode(toMap());

  factory VersionModel.fromJson(String source) =>
      VersionModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'VersionModel(version: $version, platform: $platform, url: $url, description: $description, timestamp: $timestamp, isUpdateNeed: $isUpdateNeed)';
  }

  @override
  bool operator ==(covariant VersionModel other) {
    if (identical(this, other)) return true;

    return other.version == version &&
        other.platform == platform &&
        other.url == url &&
        other.description == description &&
        other.timestamp == timestamp &&
        other.isUpdateNeed == isUpdateNeed;
  }

  @override
  int get hashCode {
    return version.hashCode ^
        platform.hashCode ^
        url.hashCode ^
        description.hashCode ^
        timestamp.hashCode ^
        isUpdateNeed.hashCode;
  }
}
