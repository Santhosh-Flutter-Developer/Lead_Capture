part of 'lead_category_bloc.dart';

abstract class LeadCategoryState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class LeadCategoryInitial extends LeadCategoryState {}

// Loading state
class LeadCategoryLoading extends LeadCategoryState {}

// Loaded state with user list
class LeadCategoryLoaded extends LeadCategoryState {
  final List<LeadCategoryModel> leadCategory;
  LeadCategoryLoaded(this.leadCategory);

  @override
  List<Object> get props => [leadCategory];
}

// Error state
class LeadCategoryError extends LeadCategoryState {
  final String message;
  LeadCategoryError(this.message);

  @override
  List<Object> get props => [message];
}
