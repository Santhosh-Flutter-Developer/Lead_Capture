part of 'chat_messages.dart';

class ChatData extends InheritedWidget {
  final String uid;
  final String currentUser;
  final bool isGroupChat;
  final ChatModel chat;
  final ChatScrollRegistry scrollRegistry;

  const ChatData({
    required this.uid,
    required this.currentUser,
    required this.isGroupChat,
    required this.chat,
    required this.scrollRegistry,
    required super.child,
    super.key,
  });

  static ChatData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChatData>()!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;
}

/// Coordinates jump-to-message + temporary highlight behaviour for the chat
/// list. A single instance is owned by [_ChatMessagesState] so that its
/// [GlobalKey]s and [highlightedUid] notifier survive rebuilds of the
/// message list (only the widget tree changes, not this object).
class ChatScrollRegistry {
  final ScrollController scrollController;

  /// Returns the currently loaded (unfiltered) messages, newest first.
  final List<MessagesModel> Function() getMessages;

  /// Loads another page of older messages. Returns true if the list grew.
  final Future<bool> Function() loadMore;

  final ValueNotifier<String?> highlightedUid = ValueNotifier<String?>(null);
  final Map<String, GlobalKey> _keys = {};

  ChatScrollRegistry({
    required this.scrollController,
    required this.getMessages,
    required this.loadMore,
  });

  GlobalKey keyFor(String uid) => _keys.putIfAbsent(uid, () => GlobalKey());

  void dispose() {
    highlightedUid.dispose();
    _keys.clear();
  }

  /// Scrolls the message list so that [uid] is visible, loading older pages
  /// first if needed, then briefly highlights the bubble.
  Future<void> scrollToMessage(String uid) async {
    var messages = getMessages();
    int guard = 0;
    while (!messages.any((m) => m.uid == uid) && guard < 30) {
      final grew = await loadMore();
      if (!grew) break;
      messages = getMessages();
      guard++;
    }
    if (!messages.any((m) => m.uid == uid)) return;
    if (!scrollController.hasClients) return;

    final revealed = await _tryReveal(uid, direction: 1);
    if (!revealed && scrollController.hasClients) {
      await scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      await _tryReveal(uid, direction: 1);
    }
  }

  Future<bool> _tryReveal(String uid, {required int direction}) async {
    for (int attempt = 0; attempt < 25; attempt++) {
      await Future.delayed(const Duration(milliseconds: 16));
      final ctx = _keys[uid]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
        _flashHighlight(uid);
        return true;
      }
      if (!scrollController.hasClients) return false;
      final pos = scrollController.position;
      final next = (pos.pixels + direction * 500).clamp(
        0.0,
        pos.maxScrollExtent,
      );
      if (next == pos.pixels) break;
      await scrollController.animateTo(
        next,
        duration: const Duration(milliseconds: 180),
        curve: Curves.linear,
      );
    }
    return false;
  }

  void _flashHighlight(String uid) {
    highlightedUid.value = uid;
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (highlightedUid.value == uid) highlightedUid.value = null;
    });
  }
}