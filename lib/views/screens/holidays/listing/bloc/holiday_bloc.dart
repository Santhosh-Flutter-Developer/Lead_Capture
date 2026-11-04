import 'package:flutter_bloc/flutter_bloc.dart';
import '/models/models.dart';
import '/services/services.dart';

// Events
abstract class HolidayEvent {}

class StreamHolidays extends HolidayEvent {}

class LoadHolidays extends HolidayEvent {}

class LoadHolidaysByYear extends HolidayEvent {
  final int year;
  LoadHolidaysByYear(this.year);
}

// States
abstract class HolidayState {}

class HolidayLoading extends HolidayState {}

class HolidayLoaded extends HolidayState {
  final List<HolidayModel> holidays;
  HolidayLoaded(this.holidays);
}

class HolidayError extends HolidayState {
  final String message;
  HolidayError(this.message);
}

// Bloc
class HolidayBloc extends Bloc<HolidayEvent, HolidayState> {
  HolidayBloc() : super(HolidayLoading()) {
    on<StreamHolidays>(_onStreamHolidays);
    on<LoadHolidays>(_onLoadHolidays);
    on<LoadHolidaysByYear>(_onLoadHolidaysByYear);
  }

  Future<void> _onStreamHolidays(
    StreamHolidays event,
    Emitter<HolidayState> emit,
  ) async {
    emit(HolidayLoading());
    try {
      final holidays = await HolidayService.getAllHolidays();
      emit(HolidayLoaded(holidays));
    } catch (e) {
      emit(HolidayError(e.toString()));
    }
  }

  Future<void> _onLoadHolidays(
    LoadHolidays event,
    Emitter<HolidayState> emit,
  ) async {
    emit(HolidayLoading());
    try {
      final holidays = await HolidayService.getAllHolidays();
      emit(HolidayLoaded(holidays));
    } catch (e) {
      emit(HolidayError(e.toString()));
    }
  }

  Future<void> _onLoadHolidaysByYear(
    LoadHolidaysByYear event,
    Emitter<HolidayState> emit,
  ) async {
    emit(HolidayLoading());
    try {
      final holidays = await HolidayService.getHolidaysByYear(event.year);
      emit(HolidayLoaded(holidays));
    } catch (e) {
      emit(HolidayError(e.toString()));
    }
  }
}
