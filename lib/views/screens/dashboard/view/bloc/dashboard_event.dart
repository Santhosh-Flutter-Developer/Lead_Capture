part of 'dashboard_bloc.dart';

abstract class DashboardEvent {}

class LoadDashboardEvent extends DashboardEvent {
  final String filter;
  final DateTimeRange? range;

  LoadDashboardEvent({required this.filter, this.range});
}

class RefreshDashboardEvent extends DashboardEvent {}
