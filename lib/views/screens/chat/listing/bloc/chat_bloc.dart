import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';
part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<ChatModel> allChats = [];

  ChatBloc() : super(ChatLoading()) {
    on<StreamChat>(_streamChat);
    on<SearchChat>(_searchChat);
  }

  Future<void> _streamChat(StreamChat event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    var cid = await Spdb.getCid();
    var user = await Spdb.getUser();
    final uid = user.uid;
    await emit.forEach(
      firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.chats.name)
          .where("participants", arrayContains: user.uid)
          .orderBy("lastMessage.timestamp", descending: true)
          .snapshots()
          .map((snapshot) {
            allChats = snapshot.docs
                .map((doc) {
                  try {
                    return ChatModel.fromMap(doc.id, doc.data());
                  } catch (e, st) {
                    debugPrint('Error parsing chat ${doc.id}: $e');
                    debugPrint('Stack trace: $st');
                    return null;
                  }
                })
                .whereType<ChatModel>()
                .where((chat) {
                  if (chat.isDeletedForUser(uid)) {
                    debugPrint('Chat ${chat.uid} filtered out for user $uid (deletedFor)');
                    return false;
                  }
                  final last = chat.lastMessage;
                  if (last == null) {
                    debugPrint('Chat ${chat.uid} filtered out (lastMessage is null)');
                    return false;
                  }

                  // More permissive filtering - allow chats with any meaningful content
                  final hasContent = (last.message.trim().isNotEmpty) ||
                      (last.type != null && last.type!.trim().isNotEmpty) ||
                      (last.messageId != null && last.messageId!.trim().isNotEmpty);
                  
                  if (!hasContent) {
                    debugPrint('Chat ${chat.uid} filtered out (no content in last message)');
                  }
                  
                  return hasContent;
                })
                .toList();
            
            debugPrint('Loaded ${allChats.length} chats for user $uid');
            return allChats;
          }),
      onData: (users) => ChatLoaded(users),
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
