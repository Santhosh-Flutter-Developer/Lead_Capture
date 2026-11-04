// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import '/models/models.dart';

class LoginLogsModel {
  final String? uid;
  final DateTime loginTime;
  final UserDataModel user;
  final LoginAlertModel loginAlert;
  LoginLogsModel({
    this.uid,
    required this.loginAlert,
    DateTime? loginTime,
    required this.user,
  }) : loginTime = loginTime ?? DateTime.now();

  LoginLogsModel copyWith({
    String? uid,
    UserDataModel? user,
    DateTime? loginTime,
    LoginAlertModel? loginAlert,
  }) {
    return LoginLogsModel(
      uid: uid ?? this.uid,
      user: user ?? this.user,
      loginTime: loginTime ?? this.loginTime,
      loginAlert: loginAlert ?? this.loginAlert,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user': user.toMap(),
      'loginTime': loginTime.millisecondsSinceEpoch,
      'loginAlert': loginAlert.toMap(),
    };
  }

  factory LoginLogsModel.fromMap(Map<String, dynamic> map) {
    return LoginLogsModel(
      uid: map['uid'] != null ? map['uid'] as String : null,
      user: map['user'] != null && map['user'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['user'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      loginTime: map['loginTime'] != null && map['loginTime'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['loginTime'] as int)
          : DateTime.now(),
      loginAlert: LoginAlertModel.fromMap(
        map['loginAlert'] as Map<String, dynamic>,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory LoginLogsModel.fromJson(String source) =>
      LoginLogsModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'LoginLogsModel(uid: $uid, user: $user, loginTime: $loginTime, loginAlert: $loginAlert)';
  }

  @override
  bool operator ==(covariant LoginLogsModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.user == user &&
        other.loginTime == loginTime &&
        other.loginAlert == loginAlert;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        user.hashCode ^
        loginTime.hashCode ^
        loginAlert.hashCode;
  }
}
