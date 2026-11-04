part of 'dashboard_bloc.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardModel data;
  DashboardLoaded(this.data);
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}
