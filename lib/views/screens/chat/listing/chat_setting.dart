import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/theme/theme.dart';

class ChatSetting extends StatelessWidget {
  const ChatSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 1,
      ),
      body: ListView(
        children: const [
          SizedBox(height: 8),
          NotificationSettingsTile(),
          Divider(height: 1),
          ApplicationSettingsTile(),
          Divider(height: 1),
          UserPreferencesTile(),
          Divider(height: 1),
          SystemMaintenanceTile(),
        ],
      ),
    );
  }
}

// ================= Notification Settings =================
class NotificationSettingsTile extends StatefulWidget {
  const NotificationSettingsTile({super.key});

  @override
  State<NotificationSettingsTile> createState() =>
      _NotificationSettingsTileState();
}

class _NotificationSettingsTileState extends State<NotificationSettingsTile> {
  bool emailNotification = true;
  bool pushNotification = true;
  bool inAppNotification = true;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Iconsax.notification, color: AppColors.primary),
      title: Text(
        'Notification Settings',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      children: [
        SwitchListTile(
          title: Text(
            'Email Notifications',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: emailNotification,
          onChanged: (val) => setState(() => emailNotification = val),
        ),
        SwitchListTile(
          title: Text(
            'Push Notifications',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: pushNotification,
          onChanged: (val) => setState(() => pushNotification = val),
        ),
        SwitchListTile(
          title: Text(
            'In-App Notifications',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: inAppNotification,
          onChanged: (val) => setState(() => inAppNotification = val),
        ),
      ],
    );
  }
}

// ================= Application Settings =================
class ApplicationSettingsTile extends StatelessWidget {
  const ApplicationSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Iconsax.setting_2, color: AppColors.primary),
      title: Text(
        'Application Settings',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      children: [
        ListTile(
          title: Text('Company Name'),
          subtitle: Text(
            'MyCompany Pvt Ltd',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.edit),
          onTap: () {},
        ),
        ListTile(
          title: Text('App Name'),
          subtitle: Text(
            'ChatApp',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.edit),
          onTap: () {},
        ),
        ListTile(
          title: Text('Timezone'),
          subtitle: Text(
            'GMT +5:30',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.edit),
          onTap: () {},
        ),
      ],
    );
  }
}

// ================= User Preferences =================
class UserPreferencesTile extends StatefulWidget {
  const UserPreferencesTile({super.key});

  @override
  State<UserPreferencesTile> createState() => _UserPreferencesTileState();
}

class _UserPreferencesTileState extends State<UserPreferencesTile> {
  bool darkTheme = false;
  bool showChats = true;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Iconsax.user, color: AppColors.primary),
      title: Text(
        'User Preferences',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      children: [
        SwitchListTile(
          title: Text('Dark Theme'),
          value: darkTheme,
          onChanged: (val) => setState(() => darkTheme = val),
        ),
        SwitchListTile(
          title: Text('Show Chats'),
          value: showChats,
          onChanged: (val) => setState(() => showChats = val),
        ),
        ListTile(
          title: Text('Language'),
          subtitle: Text('English'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
        ListTile(
          title: Text('Dashboard Layout'),
          subtitle: Text('Default'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
      ],
    );
  }
}

class SystemMaintenanceTile extends StatelessWidget {
  const SystemMaintenanceTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.settings, color: AppColors.primary),
      title: Text(
        'System Maintenance',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      children: [
        ListTile(
          title: Text('Backup Data'),
          subtitle: Text('Manual or scheduled backups'),
          trailing: const Icon(Icons.backup),
          onTap: () {},
        ),
      ],
    );
  }
}
