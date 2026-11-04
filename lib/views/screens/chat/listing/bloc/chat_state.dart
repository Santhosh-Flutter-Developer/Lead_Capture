part of 'chat_bloc.dart';

abstract class ChatState extends Equatable {
  @override
  List<Object> get props => [];
}

// Initial state
class ChatInitial extends ChatState {}

// Loading state
class ChatLoading extends ChatState {}

// Loaded state with user list
class ChatLoaded extends ChatState {
  final List<ChatModel> chats;
  ChatLoaded(this.chats);

  @override
  List<Object> get props => [chats];
}

// Error state
class ChatError extends ChatState {
  final String message;
  ChatError(this.message);

  @override
  List<Object> get props => [message];
}
