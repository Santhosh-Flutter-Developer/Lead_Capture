import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'lead_category_event.dart';
part 'lead_category_state.dart';

class LeadCategoryBloc extends Bloc<LeadCategoryEvent, LeadCategoryState> {
  List<LeadCategoryModel> allLeadCategorys = [];

  LeadCategoryBloc() : super(LeadCategoryLoading()) {
    on<StreamLeadCategory>(_streamLeadCategorys);
    on<DeleteLeadCategory>(_deleteLeadCategory);
  }

  Future<void> _streamLeadCategorys(
    StreamLeadCategory event,
    Emitter<LeadCategoryState> emit,
  ) async {
    emit(LeadCategoryLoading());
    await emit.forEach(
      ApiLive.watch({'lead_category'}, () async {
        allLeadCategorys = await LeadCategoryService.getAllLeadCategories();
        return allLeadCategorys;
      }),
      onData: (leadCategory) => LeadCategoryLoaded(leadCategory),
      onError: (error, stackTrace) {
        return LeadCategoryError("Failed to load leadCategory, $error");
      },
    );
  }

  Future<void> _deleteLeadCategory(
    DeleteLeadCategory event,
    Emitter<LeadCategoryState> emit,
  ) async {
    try {
      await LeadCategoryService.deleteLeadCategory(uid: event.uid);

      var updatedList = await LeadCategoryService.getAllLeadCategories();
      emit(LeadCategoryLoaded(updatedList));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      emit(LeadCategoryError("Failed to delete deal status: $e"));
    }
  }
}
