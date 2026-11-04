part of 'settings_bloc.dart';

abstract class SettingsEvent {}

class LoadSettingsEvent extends SettingsEvent {}

class UpdateSettingsEvent extends SettingsEvent {
  final String key;
  final dynamic value;

  UpdateSettingsEvent(this.key, this.value);
}

class TriggerManualBackup extends SettingsEvent {}
