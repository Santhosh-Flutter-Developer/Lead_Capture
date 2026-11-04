import 'package:flutter_bloc/flutter_bloc.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(SettingsInitial()) {
    on<LoadSettingsEvent>(onLoad);
    on<UpdateSettingsEvent>(onUpdate);
    on<TriggerManualBackup>(_onBackup);
  }

  Future<void> onLoad(
    LoadSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());
    try {
      final settings = await SettingsService().fetchSettings();
      emit(SettingsLoaded(settings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> onUpdate(
    UpdateSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    final current = (state as SettingsLoaded).settings;

    final updated = current.copyWith(
      emailNotification: event.key == "emailNotification" ? event.value : null,
      pushNotification: event.key == "pushNotification" ? event.value : null,
      payrollEnabled: event.key == "payrollEnabled" ? event.value : null,
      inAppNotification: event.key == "inAppNotification" ? event.value : null,
      darkTheme: event.key == "darkTheme" ? event.value : null,
      showChats: event.key == "showChats" ? event.value : null,
      appName: event.key == "appName" ? event.value : null,
      timezone: event.key == "timezone" ? event.value : null,
      language: event.key == "language" ? event.value : null,
      dashboardLayout: event.key == "dashboardLayout" ? event.value : null,
      autoBackup: event.key == "autoBackup" ? event.value : null,
    );

    emit(SettingsLoaded(updated));

    try {
      await SettingsService().updateField(event.key, event.value);
    } catch (e) {
      emit(SettingsError("Failed to update setting"));
      emit(SettingsLoaded(current)); // rollback
    }
  }

  Future<void> _onBackup(
    TriggerManualBackup event,
    Emitter<SettingsState> emit,
  ) async {}
}
