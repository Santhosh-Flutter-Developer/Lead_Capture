part of 'lead_category_bloc.dart';

abstract class LeadCategoryEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchLeadCategorys extends LeadCategoryEvent {}

class StreamLeadCategory extends LeadCategoryEvent {}

class DeleteLeadCategory extends LeadCategoryEvent {
  final String uid;
   DeleteLeadCategory(this.uid);
}
