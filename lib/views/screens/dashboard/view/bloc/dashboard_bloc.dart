import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardService dashboard;
  final String userId;
  final bool isAdmin;

  DashboardBloc({
    required this.dashboard,
    required this.userId,
    required this.isAdmin,
  }) : super(DashboardInitial()) {
    on<LoadDashboardEvent>((event, emit) async {
      emit(DashboardLoading());
      try {
        final data = await dashboard.fetchDashboardData(
          isAdmin: isAdmin,
          userId: userId,
          filter: event.filter,
          range: event.range,
        );

        emit(DashboardLoaded(data));
      } catch (e) {
        debugPrint("DashboardError: $e");
        emit(DashboardError("Failed to fetch dashboard data"));
      }
    });
  }
}
