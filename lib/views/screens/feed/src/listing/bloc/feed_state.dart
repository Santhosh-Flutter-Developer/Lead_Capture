part of 'feed_bloc.dart';

abstract class FeedState extends Equatable {
  const FeedState();

  @override
  List<Object?> get props => [];
}

class FeedInitial extends FeedState {}

class FeedLoading extends FeedState {}

class FeedLoaded extends FeedState {
  final List<FeedModel> feeds;

  // Unique per emitted state. Like/save toggles mutate the same FeedModel
  // objects in place, so without this Equatable saw "same feeds" and
  // BlocBuilder skipped the rebuild (e.g. an unsaved post stayed visible in
  // the Saved Posts tab until a manual refresh).
  final int _stamp = DateTime.now().microsecondsSinceEpoch;

  FeedLoaded(this.feeds);

  @override
  List<Object?> get props => [feeds, _stamp];
}

class FeedError extends FeedState {
  final String message;

  const FeedError(this.message);

  @override
  List<Object?> get props => [message];
}

class FeedActionInProgress extends FeedState {}

class FeedActionError extends FeedState {
  final String message;

  const FeedActionError(this.message);

  @override
  List<Object?> get props => [message];
}