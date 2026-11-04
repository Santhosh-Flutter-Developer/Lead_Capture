// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class RegionModel {
  final String? uid;
  final int id;
  final String currencySymbol;
  final String name;
  final String emoji;
  RegionModel({
    this.uid,
    required this.id,
    required this.currencySymbol,
    required this.name,
    required this.emoji,
  });

  RegionModel copyWith({
    String? uid,
    int? id,
    String? currencySymbol,
    String? name,
    String? emoji,
  }) {
    return RegionModel(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'id': id,
      'currencySymbol': currencySymbol,
      'name': name,
      'emoji': emoji,
    };
  }

  factory RegionModel.fromMap(Map<String, dynamic> map) {
    return RegionModel(
      uid: map['uid'] != null ? map['uid'] as String : null,
      id: map['id'] as int,
      currencySymbol: map['currency_symbol'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
    );
  }

  factory RegionModel.fromRefMap(Map<String, dynamic> map) {
    return RegionModel(
      uid: map['uid'] != null ? map['uid'] as String : null,
      id: map['id'] != null && map['id'] is int ? map['id'] as int : 0,
      currencySymbol:
          map['currencySymbol'] != null && map['currencySymbol'] is String
          ? map['currencySymbol'] as String
          : '',
      name: map['name'] != null && map['name'] is String
          ? map['name'] as String
          : '',
      emoji: map['emoji'] != null && map['emoji'] is String
          ? map['emoji'] as String
          : '',
    );
  }

  String toJson() => json.encode(toMap());

  factory RegionModel.fromJson(String source) =>
      RegionModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'RegionModel(uid: $uid, id: $id, currencySymbol: $currencySymbol, name: $name, emoji: $emoji)';
  }

  @override
  bool operator ==(covariant RegionModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.id == id &&
        other.currencySymbol == currencySymbol &&
        other.name == name &&
        other.emoji == emoji;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        id.hashCode ^
        currencySymbol.hashCode ^
        name.hashCode ^
        emoji.hashCode;
  }
}

class StateModel {
  final String? uid;
  final int id;
  final String name;
  final String type;
  StateModel({
    this.uid,
    required this.id,
    required this.name,
    required this.type,
  });

  StateModel copyWith({String? uid, int? id, String? name, String? type}) {
    return StateModel(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'uid': uid, 'id': id, 'name': name, 'type': type};
  }

  factory StateModel.fromMap(Map<String, dynamic> map) {
    return StateModel(
      uid: map['uid'] != null ? map['uid'] as String : null,
      id: map['id'] != null && map['id'] is int ? map['id'] as int : 0,
      name: map['name'] != null && map['name'] is String
          ? map['name'] as String
          : '',
      type: map['type'] != null && map['type'] is String
          ? map['type'] as String
          : '',
    );
  }

  String toJson() => json.encode(toMap());

  factory StateModel.fromJson(String source) =>
      StateModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StateModel(uid: $uid, id: $id, name: $name, type: $type)';
  }

  @override
  bool operator ==(covariant StateModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.id == id &&
        other.name == name &&
        other.type == type;
  }

  @override
  int get hashCode {
    return uid.hashCode ^ id.hashCode ^ name.hashCode ^ type.hashCode;
  }
}

class CityModel {
  final String? uid;
  final int id;
  final String name;
  CityModel({this.uid, required this.id, required this.name});

  CityModel copyWith({String? uid, int? id, String? name}) {
    return CityModel(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'uid': uid, 'id': id, 'name': name};
  }

  factory CityModel.fromMap(Map<String, dynamic> map) {
    return CityModel(
      uid: map['uid'] != null && map['uid'] is String
          ? map['uid'] as String
          : null,
      id: map['id'] != null && map['id'] is int ? map['id'] as int : 0,
      name: map['name'] != null && map['name'] is String
          ? map['name'] as String
          : '',
    );
  }

  String toJson() => json.encode(toMap());

  factory CityModel.fromJson(String source) =>
      CityModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'CityModel(uid: $uid, id: $id, name: $name)';
  }

  @override
  bool operator ==(covariant CityModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid && other.id == id && other.name == name;
  }

  @override
  int get hashCode {
    return uid.hashCode ^ id.hashCode ^ name.hashCode;
  }
}

class DistrictModel {
  final String? uid;
  final int id;
  final String name;
  DistrictModel({this.uid, required this.id, required this.name});

  DistrictModel copyWith({String? uid, int? id, String? name}) {
    return DistrictModel(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'uid': uid, 'id': id, 'name': name};
  }

  factory DistrictModel.fromMap(Map<String, dynamic> map) {
    return DistrictModel(
      uid: map['uid'] != null && map['uid'] is String
          ? map['uid'] as String
          : null,
      id: map['id'] != null && map['id'] is int ? map['id'] as int : 0,
      name: map['name'] != null && map['name'] is String
          ? map['name'] as String
          : '',
    );
  }

  String toJson() => json.encode(toMap());

  factory DistrictModel.fromJson(String source) =>
      DistrictModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'DistrictModel(uid: $uid, id: $id, name: $name)';

  @override
  bool operator ==(covariant DistrictModel other) {
    if (identical(this, other)) return true;
    return other.uid == uid && other.id == id && other.name == name;
  }

  @override
  int get hashCode => uid.hashCode ^ id.hashCode ^ name.hashCode;
}