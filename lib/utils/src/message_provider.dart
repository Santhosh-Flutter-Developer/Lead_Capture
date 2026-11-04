import 'package:flutter/material.dart';
import '/models/models.dart';

class MessageProvider extends ChangeNotifier {
  bool _isEdit = false;
  bool _isReply = false;
  bool _isRecording = false;
  MessagesModel? _chat;

  bool get isEdit => _isEdit;
  bool get isReply => _isReply;
  bool get isRecording => _isRecording;

  MessagesModel? get chat => _chat;

  void editMessage(MessagesModel? chat) {
    _isEdit = true;
    _isReply = false;
    _chat = chat;
    notifyListeners();
  }

  void replyMessage(MessagesModel? chat) {
    _isEdit = false;
    _isReply = true;
    _chat = chat;
    notifyListeners();
  }

  void clearMessage() {
    _isEdit = false;
    _isReply = false;
    _chat = null;
    notifyListeners();
  }

  void startRecording() {
    _isRecording = true;
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    notifyListeners();
  }
}
