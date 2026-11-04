part of 'feed_bloc.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadFeeds extends FeedEvent {}

class RefreshFeeds extends FeedEvent {}

class ToggleLike extends FeedEvent {
  final String feedId;
  final String userId;

  const ToggleLike({required this.feedId, required this.userId});

  @override
  List<Object?> get props => [feedId, userId];
}

class ToggleSaveFeed extends FeedEvent {
  final String feedId;
  final String userId;

  const ToggleSaveFeed({required this.feedId, required this.userId});

  @override
  List<Object?> get props => [feedId, userId];
}

class AddComment extends FeedEvent {
  final String feedId;
  final String userId;
  final String content;

  const AddComment({
    required this.feedId,
    required this.userId,
    required this.content,
  });

  @override
  List<Object?> get props => [feedId, userId, content];
}

class VotePoll extends FeedEvent {
  final String feedId;
  final String optionId;

  const VotePoll({required this.feedId, required this.optionId});

  @override
  List<Object?> get props => [feedId, optionId];
}
