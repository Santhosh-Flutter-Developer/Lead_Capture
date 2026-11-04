// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import '/constants/constants.dart';

class UserDataModel {
  final String uid;
  final String name;
  final String? profilePic;
  final String? desc;
  final UserType userType;
  UserDataModel({
    required this.uid,
    required this.name,
    this.profilePic,
    this.desc,
    required this.userType,
  });

  UserDataModel copyWith({
    String? uid,
    String? name,
    String? profilePic,
    String? desc,
    UserType? userType,
  }) {
    return UserDataModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      profilePic: profilePic ?? this.profilePic,
      desc: desc ?? this.desc,
      userType: userType ?? this.userType,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'name': name,
      'profilePic': profilePic,
      'desc': desc,
      'userType': userType.name,
    };
  }

  factory UserDataModel.fromMap(Map<String, dynamic> map) {
    return UserDataModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      profilePic: map['profilePic']?.toString(),
      desc: map['desc']?.toString(),
      userType: UserType.values.firstWhere(
        (e) => e.name == map['userType']?.toString(),
        orElse: () => UserType.employee,
      ),
    );
  }

  factory UserDataModel.fromEmptyMap() {
    return UserDataModel(
      uid: '',
      name: 'User',
      userType: UserType.employee,
      profilePic: AppStrings.emptyProfilePhotoUrl,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserDataModel.fromJson(String source) =>
      UserDataModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'UserDataModel(uid: $uid, name: $name, profilePic: $profilePic, desc: $desc, userType: $userType)';
  }

  @override
  bool operator ==(covariant UserDataModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.name == name &&
        other.profilePic == profilePic &&
        other.desc == desc &&
        other.userType == userType;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        profilePic.hashCode ^
        desc.hashCode ^
        userType.hashCode;
  }
}
