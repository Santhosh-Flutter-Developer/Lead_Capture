class SettingsModel {
  final String? uid;
  final bool emailNotification;
  final bool pushNotification;
  final bool inAppNotification;
  final bool showChats;
  final String companyName;
  final String appName;
  final String timezone;
  final String language;
  final String dashboardLayout;
  final bool autoBackup;
  final bool payrollEnabled;

  SettingsModel({
    this.uid,
    required this.emailNotification,
    required this.pushNotification,
    required this.inAppNotification,
    required this.showChats,
    required this.companyName,
    required this.appName,
    required this.timezone,
    required this.language,
    required this.dashboardLayout,
    required this.autoBackup,
    required this.payrollEnabled,
  });

  SettingsModel copyWith({
    String? uid,
    bool? emailNotification,
    bool? pushNotification,
    bool? inAppNotification,
    bool? darkTheme,
    bool? showChats,
    String? companyName,
    String? appName,
    String? timezone,
    String? language,
    String? dashboardLayout,
    bool? autoBackup,
    bool? payrollEnabled,
  }) {
    return SettingsModel(
      uid: uid ?? this.uid,
      emailNotification: emailNotification ?? this.emailNotification,
      pushNotification: pushNotification ?? this.pushNotification,
      inAppNotification: inAppNotification ?? this.inAppNotification,
      showChats: showChats ?? this.showChats,
      companyName: companyName ?? this.companyName,
      appName: appName ?? this.appName,
      timezone: timezone ?? this.timezone,
      language: language ?? this.language,
      dashboardLayout: dashboardLayout ?? this.dashboardLayout,
      autoBackup: autoBackup ?? this.autoBackup,
      payrollEnabled: payrollEnabled ?? this.payrollEnabled,
    );
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      uid: map['uid'],
      emailNotification: map['emailNotification'] ?? true,
      pushNotification: map['pushNotification'] ?? true,
      inAppNotification: map['inAppNotification'] ?? true,
      showChats: map['showChats'] ?? true,
      companyName: map['companyName'] ?? "",
      appName: map['appName'] ?? "",
      timezone: map['timezone'] ?? "",
      language: map['language'] ?? "",
      dashboardLayout: map['dashboardLayout'] ?? "",
      autoBackup: map['autoBackup'] ?? false,
      payrollEnabled: map['payrollEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "emailNotification": emailNotification,
      "pushNotification": pushNotification,
      "inAppNotification": inAppNotification,
      "showChats": showChats,
      "companyName": companyName,
      "appName": appName,
      "timezone": timezone,
      "language": language,
      "dashboardLayout": dashboardLayout,
      "autoBackup": autoBackup,
      "payrollEnabled": payrollEnabled,
    };
  }
}
