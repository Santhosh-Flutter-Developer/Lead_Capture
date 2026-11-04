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

  const FeedLoaded(this.feeds);

  @override
  List<Object?> get props => [feeds];
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
