part of 'settings_bloc.dart';

abstract class SettingsState {}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final SettingsModel settings;
  SettingsLoaded(this.settings);
}

class SettingsError extends SettingsState {
  final String message;
  SettingsError(this.message);
}
