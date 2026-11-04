part of 'chat_bloc.dart';

abstract class ChatEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchChat extends ChatEvent {}

class StreamChat extends ChatEvent {}

class SearchChat extends ChatEvent {
  final String query;
  SearchChat(this.query);
}
