import 'package:flutter_bloc/flutter_bloc.dart';
import '/models/models.dart';
import '/services/services.dart';

// Events
abstract class CompanyEvent {}

class StreamCompanies extends CompanyEvent {}

class LoadCompanies extends CompanyEvent {}

// States
abstract class CompanyState {}

class CompanyLoading extends CompanyState {}

class CompanyLoaded extends CompanyState {
  final List<CompanyModel> companies;
  CompanyLoaded(this.companies);
}

class CompanyError extends CompanyState {
  final String message;
  CompanyError(this.message);
}

// Bloc
class CompanyBloc extends Bloc<CompanyEvent, CompanyState> {
  CompanyBloc() : super(CompanyLoading()) {
    on<StreamCompanies>(_onStreamCompanies);
    on<LoadCompanies>(_onLoadCompanies);
  }

  Future<void> _onStreamCompanies(
    StreamCompanies event,
    Emitter<CompanyState> emit,
  ) async {
    emit(CompanyLoading());
    try {
      final companies = await CompanyService.getAllCompanies();
      emit(CompanyLoaded(companies));
    } catch (e) {
      emit(CompanyError(e.toString()));
    }
  }

  Future<void> _onLoadCompanies(
    LoadCompanies event,
    Emitter<CompanyState> emit,
  ) async {
    emit(CompanyLoading());
    try {
      final companies = await CompanyService.getAllCompanies();
      emit(CompanyLoaded(companies));
    } catch (e) {
      emit(CompanyError(e.toString()));
    }
  }
}
