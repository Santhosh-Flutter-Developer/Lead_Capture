import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/services/services.dart';
import '/models/models.dart';

part 'feed_event.dart';
part 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc() : super(FeedInitial()) {
    on<LoadFeeds>(_onLoadFeeds);
    on<RefreshFeeds>(_onRefreshFeeds);
    on<ToggleLike>(_onToggleLike);
    on<AddComment>(_onAddComment);
    on<VotePoll>(_onVotePoll);
    on<ToggleSaveFeed>(_onToggleSaveFeed);
  }

  Future<void> _onLoadFeeds(LoadFeeds event, Emitter<FeedState> emit) async {
    emit(FeedLoading());
    try {
      final feeds = await FeedService.getAllFeeds();
      emit(FeedLoaded(feeds));
    } catch (e) {
      emit(FeedError(e.toString()));
    }
  }

  Future<void> _onRefreshFeeds(
    RefreshFeeds event,
    Emitter<FeedState> emit,
  ) async {
    try {
      final feeds = await FeedService.getAllFeeds();
      emit(FeedLoaded(feeds));
    } catch (e) {
      emit(FeedError(e.toString()));
    }
  }

  Future<void> _onToggleLike(ToggleLike event, Emitter<FeedState> emit) async {
    if (state is! FeedLoaded) return;
    final currentState = state as FeedLoaded;
    final feeds = List<FeedModel>.from(currentState.feeds);
    final index = feeds.indexWhere((f) => f.uid == event.feedId);
    if (index == -1) return;

    final feed = feeds[index];

    // Optimistic update
    bool isLiked = feed.reactions.any((r) => r.userId == event.userId);
    feed.reactions.removeWhere((r) => r.userId == event.userId);
    if (!isLiked) {
      feed.reactions.add(ReactionModel(userId: event.userId, type: 'like'));
    }

    emit(FeedLoaded(feeds));

    try {
      await FeedService.toggleReaction(
        feedId: event.feedId,
        userId: event.userId,
        type: 'like',
      );
    } catch (e) {
      // Revert on error
      if (isLiked) {
        feed.reactions.add(ReactionModel(userId: event.userId, type: 'like'));
      } else {
        feed.reactions.removeWhere((r) => r.userId == event.userId);
      }
      emit(FeedLoaded(feeds));
    }
  }

  Future<void> _onAddComment(AddComment event, Emitter<FeedState> emit) async {
    if (state is! FeedLoaded) return;
    final currentState = state as FeedLoaded;
    final feeds = List<FeedModel>.from(currentState.feeds);
    final index = feeds.indexWhere((f) => f.uid == event.feedId);
    if (index == -1) return;

    emit(FeedActionInProgress());

    try {
      final newComment = CommentModel(
        commentId: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: event.userId,
        authorName: 'You', // Or fetch user name
        authorAvatar: '',
        content: event.content,
        createdAt: DateTime.now(),
      );

      await FeedService.addComment(feedId: event.feedId, comment: newComment);
      feeds[index].comments!.insert(0, newComment);
      emit(FeedLoaded(feeds));
    } catch (e) {
      emit(FeedActionError('Failed to add comment'));
      emit(FeedLoaded(feeds));
    }
  }

  Future<void> _onVotePoll(VotePoll event, Emitter<FeedState> emit) async {
    if (state is! FeedLoaded) return;
    final currentState = state as FeedLoaded;
    final feeds = List<FeedModel>.from(currentState.feeds);
    final index = feeds.indexWhere((f) => f.uid == event.feedId);
    if (index == -1) return;

    try {
      await FeedService.votePoll(
        feedId: event.feedId,
        optionId: event.optionId,
      );
      // Re-fetch feeds after vote
      final updatedFeeds = await FeedService.getAllFeeds();
      emit(FeedLoaded(updatedFeeds));
    } catch (e) {
      emit(FeedActionError('Failed to vote poll'));
    }
  }

  Future<void> _onToggleSaveFeed(ToggleSaveFeed event, Emitter<FeedState> emit) async {
    if (state is! FeedLoaded) return;
    final currentState = state as FeedLoaded;
    final feeds = List<FeedModel>.from(currentState.feeds);
    final index = feeds.indexWhere((f) => f.uid == event.feedId);
    if (index == -1) return;

    final feed = feeds[index];

    // Optimistic update
    bool isSaved = feed.savedBy.contains(event.userId);
    if (isSaved) {
      feed.savedBy.remove(event.userId);
    } else {
      feed.savedBy.add(event.userId);
    }

    emit(FeedLoaded(feeds));

    try {
      await FeedService.toggleSaveFeed(
        feedId: event.feedId,
        userId: event.userId,
      );
    } catch (e) {
      // Revert on error
      if (isSaved) {
        feed.savedBy.add(event.userId);
      } else {
        feed.savedBy.remove(event.userId);
      }
      emit(FeedLoaded(feeds));
    }
  }
}
