import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  List<ChatModel> allChats = [];

  ChatBloc() : super(ChatLoading()) {
    on<StreamChat>(_streamChat);
    on<SearchChat>(_searchChat);
  }

  /// chats.php `threads`, polled every 15 s and after every chat change.
  Future<void> _streamChat(StreamChat event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    await emit.forEach<List<ChatModel>>(
      ChatService.watchChats(),
      onData: (chats) {
        allChats = chats;
        return ChatLoaded(chats);
      },
      onError: (error, stackTrace) => ChatError("Failed to load chats, $error"),
    );
  }

  void _searchChat(SearchChat event, Emitter<ChatState> emit) {
    // if (event.query.isEmpty) {
    //   emit(ChatLoaded(allChats));
    //   return;
    // }

    // List<ChatModel> filteredChat = allChats.where((ps) {
    //   return ps.chatNumber
    //       .toString()
    //       .toLowerCase()
    //       .contains(event.query.toLowerCase());
    // }).toList();

    // emit(ChatLoaded(filteredChat));
  }
}
