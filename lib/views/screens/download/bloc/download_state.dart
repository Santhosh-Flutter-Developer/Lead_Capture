
import 'package:leadcapture/models/src/download_model.dart';

abstract class DownloadHistoryState {}

class DownloadHistoryLoading extends DownloadHistoryState {}

class DownloadHistoryLoaded extends DownloadHistoryState {
  final List<DownloadHistoryModel> items;
  DownloadHistoryLoaded(this.items);
}

class DownloadHistoryError extends DownloadHistoryState {
  final String message;
  DownloadHistoryError(this.message);
}
