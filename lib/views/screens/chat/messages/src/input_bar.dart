part of 'chat_messages.dart';

class ChatInputBar extends StatefulWidget {
  final ChatModel chat;
  final String? threadId;
  const ChatInputBar({super.key, required this.chat, this.threadId});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final List<PlatformFile> _pickedFiles = [];
  bool _showMentionList = false;
  List<MentionModel> _allUsers = [];
  List<MentionModel> _filteredUsers = [];
  bool get hasText => _controller.text.trim().isNotEmpty;
  final List<MentionModel> _mentions = [];
  // Tracks the text length from the previous change so we can tell whether
  // the user is typing (inserting) or deleting. The mention dropdown should
  // only ever open because the user typed "@" — never as a side effect of
  // backspacing/deleting text.
  int _previousTextLength = 0;
  String getExt(String path) {
    return path.split('?').first.split('#').first.split('.').last.toLowerCase();
  }

  String _getMimeType(String ext) {
    ext = ext.toLowerCase();
    // NOTE: previously referenced `imageExtensions`/`videoExtensions`/
    // `audioExtensions` without defining them anywhere in scope — every
    // other usage in this file declares its own local copy inside a
    // different method, so this was an undefined-identifier compile error.
    // 'm4a' is included so recorded voice notes (see AudioRecorder) are
    // correctly classified as audio.
    const imageExtensions = ["png", "jpg", "jpeg", "webp", "bmp", "gif", "tiff"];
    const videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    const audioExtensions = ['mp3', 'wav', 'aac', 'm4a'];
    if (imageExtensions.contains(ext)) return 'image/$ext';
    if (videoExtensions.contains(ext)) return 'video/$ext';
    if (audioExtensions.contains(ext)) return 'audio/$ext';

    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      withData: kIsWeb,
      allowedExtensions: [
        'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'tiff', // images
        'mp4', 'mov', 'avi', 'mkv', 'webm', // videos
        'mp3', 'wav', 'aac', 'm4a', // audio
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', // documents
      ],
    );

    if (files != null && files.files.isNotEmpty) {
      setState(() {
        _pickedFiles.addAll(files.files);
      });
    }
  }

  void _removeFile(int index) {
    final removed = _pickedFiles[index];
    setState(() {
      _pickedFiles.removeAt(index);
    });
    AttachmentIntake.discard(removed); // temp copy made by paste / drop
  }

  // ── Paste & drag-and-drop attachments ─────────────────────────────────
  // Everything that arrives from the clipboard (screenshots, copied images,
  // copied files) or from a drop becomes a PlatformFile in [_pickedFiles], so
  // the existing preview strip and upload code handle it unchanged.

  /// Updated in build(); false for read-only channels.
  bool _canPost = true;

  /// Asked by the drop zone before it accepts a drag.
  bool get canAcceptAttachments => mounted && _canPost;

  /// Called by the drop zone / paste handlers with what was read.
  void receiveImport(AttachmentImport result) {
    if (!mounted) return;
    if (result.files.isNotEmpty) {
      setState(() => _pickedFiles.addAll(result.files));
      // Desktop / web: keep typing flow (Enter sends). Don't pop the
      // keyboard on phones.
      if (!kIsMobile) focusNode.requestFocus();
    }
    if (result.tooLarge > 0) {
      FlushBar.show(
        context,
        result.tooLarge == 1
            ? 'That file is too large to attach here (max 100 MB).'
            : '${result.tooLarge} files are too large to attach here (max 100 MB).',
        isSuccess: false,
      );
    }
    if (result.failed > 0) {
      FlushBar.show(
        context,
        result.failed == 1
            ? 'Could not attach that item. Folders are not supported.'
            : 'Could not attach ${result.failed} items. Folders are not supported.',
        isSuccess: false,
      );
    }
  }

  /// Desktop / mobile: look at the system clipboard. Plain text is left to
  /// the normal text paste; images and copied files become attachments.
  Future<void> _pasteAttachmentsFromClipboard({bool explicit = false}) async {
    try {
      final result = await AttachmentIntake.fromSystemClipboard();
      if (!mounted) return;
      if (result.isEmpty) {
        if (explicit) {
          FlushBar.show(
            context,
            'No image or file found on the clipboard.',
            isSuccess: false,
          );
        }
        return;
      }
      receiveImport(result);
    } catch (e) {
      debugPrint('Paste attachment error: $e');
      if (explicit && mounted) {
        FlushBar.show(
          context,
          'Could not read the clipboard.',
          isSuccess: false,
        );
      }
    }
  }

  /// Web: browser paste event (needs no permission prompt, works in Firefox).
  Future<void> _onWebPaste(ClipboardReadEvent event) async {
    // Only react when the message box is the focused element; otherwise leave
    // the browser's default paste alone (search boxes etc.).
    if (!focusNode.hasFocus || !_canPost) return;
    // Asking for the reader takes over the paste, so text is inserted by hand
    // when there is nothing to attach.
    final reader = await event.getClipboardReader();
    final result = await AttachmentIntake.fromClipboardReader(reader);
    if (!mounted) return;
    if (!result.isEmpty) {
      receiveImport(result);
      return;
    }
    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && mounted) _insertTextAtCursor(text);
    }
  }

  void _insertTextAtCursor(String text) {
    final v = _controller.value;
    final sel = v.selection;
    final start = sel.isValid ? sel.start : v.text.length;
    final end = sel.isValid ? sel.end : v.text.length;
    _controller.value = v.copyWith(
      text: v.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
  }

  /// Android keyboards (Gboard clipboard chip, stickers, GIFs) insert images
  /// straight into the text field.
  Future<void> _onKeyboardContent(KeyboardInsertedContent content) async {
    final data = content.data;
    if (data == null || data.isEmpty) return;
    final file = await AttachmentIntake.fromBytes(
      data,
      mimeType: content.mimeType,
    );
    if (file != null) receiveImport(AttachmentImport(files: [file]));
  }

  ClipboardEvents? _webClipboardEvents;

  MessageProvider? _messageProvider;
  bool _isReply = false;
  bool _isEdit = false;
  MessagesModel? _chat;

  // ── Voice message state ───────────────────────────────────────────────
  final VoiceRecorder _voice = VoiceRecorder();

  /// A touch press-and-hold recording is in progress.
  bool _voiceHeld = false;

  /// The finger has slid far enough left that releasing will cancel.
  bool _voiceWillCancel = false;
  double _voiceDragDx = 0;
  bool _voiceFinishing = false;
  int _voiceUploads = 0;

  static const double _cancelDistance = 110;
  static const double _lockDistance = 80;

  bool get _voiceActive =>
      _voice.state == VoiceRecorderState.recording ||
      _voice.state == VoiceRecorderState.paused ||
      _voiceHeld;
  // String? replyForName;
  // String? replyForAvatar;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode(
      onKeyEvent: (node, event) {
        // Ctrl/Cmd+V: if the clipboard holds an image or files, attach them.
        // Text paste still runs normally (we return `ignored` below). On web
        // this is done by the paste-event listener instead.
        if (!kIsWeb &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          _pasteAttachmentsFromClipboard();
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (!HardwareKeyboard.instance.isShiftPressed) {
            _sendMessage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
    _loadUsers();
    _controller.addListener(_onTextChanged);

    // Web: browser paste events (null on every other platform).
    _webClipboardEvents = ClipboardEvents.instance;
    _webClipboardEvents?.registerPasteEventListener(_onWebPaste);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageProvider = Provider.of<MessageProvider>(context, listen: false);
      _messageProvider?.addListener(_onMessageProviderChange);
    });
  }

  Future<void> _loadUsers() async {
    // Mentions are available in both group chats and one-to-one chats, and
    // list every active employee/admin in the company — not just the
    // participants of the current chat — so anyone can be tagged.
    try {
      final employees = await EmployeeService.getAllEmployees(
        excludeCurrentUser: true,
      );
      final admins = await AdminService.getAllAdmins(
        excludeCurrentUser: true,
      );

      List<MentionModel> users = [
        ...employees.map(
          (user) => MentionModel(
            uid: user.uid ?? '',
            name: user.name,
            image: user.profileImageUrl,
          ),
        ),
        ...admins.map(
          (user) => MentionModel(
            uid: user.uid ?? '',
            name: user.name,
            image: user.profileImageUrl,
          ),
        ),
      ];

      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) return;
      setState(() {
        _allUsers = users;
        debugPrint("Mention users: ${_allUsers.map((e) => e.name)}");
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error loading mention users: $e");
    }
  }

  void _onMessageProviderChange() {
    if (!mounted) return;

    setState(() {
      _isReply = _messageProvider?.isReply ?? false;
      _isEdit = _messageProvider?.isEdit ?? false;
      _chat = _messageProvider?.chat;
    });

    if (_isEdit && _chat != null) {
      // Wait until the widget is ready before updating controller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.value = TextEditingValue(
          text: _chat?.message ?? '',
          selection: TextSelection.collapsed(
            offset: _chat?.message.length ?? 0,
          ),
        );
      });
    }
  }

  /// Re-focuses the message field, forces its text caret to actually be
  /// visible/blinking again, and explicitly asks the platform to show the
  /// soft keyboard.
  ///
  /// Two separate platform quirks show up after we programmatically insert
  /// a mention (or a mention dropdown closes):
  /// - On Android, tapping something outside the field can close the
  ///   on-screen keyboard even though the field still logically holds
  ///   focus (`focusNode.hasFocus` stays true) — a plain `requestFocus()`
  ///   is a no-op in that case since focus never actually left.
  /// - On web/desktop, changing `controller.text`/`selection` while the
  ///   field already has focus doesn't always restart the caret's blink
  ///   animation, so the cursor can end up invisible until the user clicks
  ///   back into the field.
  ///
  /// Forcing a real unfocus -> refocus transition (instead of a no-op
  /// `requestFocus()` on an already-focused node) fixes both: it makes
  /// Flutter genuinely restart the caret blink, and re-triggers the
  /// platform text-input connection so the keyboard reliably reappears.
  void _ensureFocusAndKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // The field is no longer re-created when the list toggles, so it keeps
      // focus; only re-request it if it genuinely lost it.
      if (!focusNode.hasFocus) {
        FocusScope.of(context).requestFocus(focusNode);
      }
      try {
        await SystemChannels.textInput.invokeMethod('TextInput.show');
      } catch (_) {
        // Ignore — not fatal if the platform doesn't support this.
      }
    });
  }

  void _onTextChanged() {
    // Mentions are available in both group chats and one-to-one chats.
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    final isDeleting = text.length < _previousTextLength;
    _previousTextLength = text.length;

    if (cursorPos < 0) return;

    final subText = text.substring(0, cursorPos);
    final match = RegExp(r'(?:^|\s)@([a-zA-Z0-9_]*)$').firstMatch(subText);

    _mentions.removeWhere((m) => !text.contains('@${m.name}'));

    // Never open the dropdown as a result of deleting/backspacing text —
    // only when the user actively types "@". If they're deleting, simply
    // make sure any open dropdown is closed and stop there.
    if (isDeleting) {
      if (_showMentionList) {
        setState(() {
          _showMentionList = false;
        });
        _ensureFocusAndKeyboard();
      }
      return;
    }

    if (match != null) {
      final query = match.group(1)?.toLowerCase() ?? '';

      setState(() {
        _showMentionList = true;
        _filteredUsers = _allUsers.where((user) {
          return user.name.toLowerCase().contains(query);
        }).toList();
      });
    } else {
      final wasShowingMentionList = _showMentionList;

      setState(() {
        _showMentionList = false;
      });

      // Only nudge focus/keyboard back when the dropdown was actually open
      // and just closed (e.g. backspacing an "@name" tag away) — not on
      // every ordinary keystroke, which would otherwise trigger this on
      // every character typed outside a mention.
      if (wasShowingMentionList) {
        _ensureFocusAndKeyboard();
      }
    }
  }

  void _selectMention(MentionModel user) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final subText = text.substring(0, cursorPos);

    final match = RegExp(r'(?:^|\s)@([a-zA-Z0-9_]*)$').firstMatch(subText);

    if (match != null) {
      final mentionStart = match.start + (subText[match.start] == ' ' ? 1 : 0);

      final mentionText = '@${user.name} ';
      final end = mentionStart + mentionText.length;

      final newText = text.replaceRange(mentionStart, cursorPos, mentionText);

      // One atomic update (text + caret) => the listener runs once.
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: end),
      );

      // Remove duplicate mention
      _mentions.removeWhere((m) => m.uid == user.uid);

      _mentions.add(
        MentionModel(
          uid: user.uid,
          name: user.name,
          start: mentionStart,
          end: end,
        ),
      );

      setState(() {
        _showMentionList = false;
      });

      // Tapping a mention in the dropdown list can close the on-screen
      // keyboard on mobile even though the field keeps logical focus.
      // Re-focus and re-show the keyboard once the tag has been inserted
      // so the user can keep typing/tagging right away.
      _ensureFocusAndKeyboard();
    }
  }

  Future<List<FileModel>> _uploadFiles(List<PlatformFile> files) async {
    List<FileModel> uploadedFiles = [];

    for (final pf in files) {
      final fileName = pf.name;
      final ext = fileName.split('.').last.toLowerCase();
      final size = pf.size;

      final String url;
      if (kIsWeb) {
        url = await StorageService.uploadBytes(
          bytes: pf.bytes!,
          fileName: fileName,
          folder: StorageFolder.chats,
        );
      } else {
        url = await StorageService.uploadFile(
          file: File(pf.path!),
          folder: StorageFolder.chats,
        );
      }

      uploadedFiles.add(
        FileModel(
          url: url,
          name: fileName,
          size: (size / 1024).round(),
          extension: ext,
          mimeType: _getMimeType(ext),
          createdAt: DateTime.now(),
        ),
      );
    }
    return uploadedFiles;
  }

  @override
  void dispose() {
    _messageProvider?.removeListener(_onMessageProviderChange);
    _webClipboardEvents?.unregisterPasteEventListener(_onWebPaste);
    // Temp copies made by paste / drop that were never sent.
    for (final f in _pickedFiles) {
      AttachmentIntake.discard(f);
    }
    _voice.dispose();
    _controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────
  // Voice messages (WhatsApp style)
  //
  //  • Touch devices: press & hold the mic, release to send, slide left to
  //    cancel, slide up to lock hands-free. A quick tap also starts a
  //    locked recording.
  //  • Desktop / web (mouse): click the mic to start, click send to send,
  //    trash to cancel, pause to pause.
  // ───────────────────────────────────────────────────────────────────

  Future<void> _beginVoice({required bool held}) async {
    if (_voice.isActive || _voiceFinishing) return;
    setState(() {
      _voiceHeld = held;
      _voiceWillCancel = false;
      _voiceDragDx = 0;
    });
    if (_isTouchPlatform()) HapticFeedback.mediumImpact();

    final ok = await _voice.start();
    if (!ok && mounted) {
      setState(() => _voiceHeld = false);
      FlushBar.show(
        context,
        _voice.lastError ?? 'Could not start recording',
        isSuccess: false,
      );
    }
  }

  void _onVoiceMove(LongPressMoveUpdateDetails d) {
    if (!_voiceHeld) return;
    final dx = d.offsetFromOrigin.dx;
    final dy = d.offsetFromOrigin.dy;

    if (dy < -_lockDistance) {
      // Slid up: keep recording hands-free.
      HapticFeedback.selectionClick();
      setState(() {
        _voiceHeld = false;
        _voiceWillCancel = false;
        _voiceDragDx = 0;
      });
      return;
    }

    final willCancel = dx < -_cancelDistance;
    if (willCancel != _voiceWillCancel) HapticFeedback.selectionClick();
    setState(() {
      _voiceDragDx = dx.clamp(-_cancelDistance * 1.4, 0.0);
      _voiceWillCancel = willCancel;
    });
  }

  void _onVoiceHoldEnd() {
    if (!_voiceHeld) return; // locked: the user finishes with the buttons
    _finishVoice(send: !_voiceWillCancel);
  }

  Future<void> _finishVoice({required bool send}) async {
    if (_voiceFinishing) return;
    _voiceFinishing = true;
    final elapsed = _voice.elapsed;
    if (mounted) {
      setState(() {
        _voiceHeld = false;
        _voiceWillCancel = false;
        _voiceDragDx = 0;
      });
    }

    try {
      if (!send) {
        await _voice.cancel();
        return;
      }
      final recording = await _voice.stop();
      if (recording == null) {
        if (mounted && elapsed < VoiceRecorder.minDuration) {
          FlushBar.show(
            context,
            'Hold the mic and speak, then release to send',
            isSuccess: false,
          );
        }
        return;
      }
      // Don't block the composer while uploading.
      unawaited(_sendVoiceMessage(recording));
    } finally {
      _voiceFinishing = false;
    }
  }

  Future<void> _sendVoiceMessage(VoiceRecording recording) async {
    if (!mounted) return;
    final uid = ChatData.of(context).uid;
    final replyId = _isReply ? _chat?.uid : null;
    final threadId = widget.threadId;

    // Voice message consumes the pending reply, like a normal message.
    _messageProvider?.clearMessage();

    setState(() => _voiceUploads++);
    try {
      final Uint8List bytes;
      if (kIsWeb) {
        // `blob:` URLs only work inside this browser tab, so read the bytes
        // now and upload them like any other picked file.
        final response = await http.get(Uri.parse(recording.path));
        if (response.statusCode != 200) {
          throw Exception(
            'Failed to read recorded audio (status ${response.statusCode})',
          );
        }
        bytes = response.bodyBytes;
      } else {
        bytes = await File(recording.path).readAsBytes();
      }

      final ext = recording.extension;
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final url = await StorageService.uploadBytes(
        bytes: bytes,
        fileName: fileName,
        folder: StorageFolder.chats,
      );

      final file = FileModel(
        url: url,
        name: fileName,
        size: (bytes.length / 1024).round(),
        extension: ext,
        mimeType: _getMimeType(ext),
        createdAt: DateTime.now(),
        isVoice: true,
        durationMs: recording.duration.inMilliseconds,
        waveform: recording.waveform,
      );

      await ChatService.sendChatMessage(
        chatId: uid,
        message: '',
        attachments: [file],
        replyFor: replyId,
        mentions: const [],
        threadId: threadId,
      );
      ChatService.sendNotification(
        chatId: uid,
        message: '🎤 Voice message',
        isChat: true,
      );

      if (!kIsWeb) {
        try {
          await File(recording.path).delete();
        } catch (_) {}
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        FlushBar.show(
          context,
          'Failed to send voice message. Please try again.',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) setState(() => _voiceUploads--);
    }
  }

  late final FocusNode focusNode;

  // Keeps the TextField's State alive when the mention list is inserted above
  // it in the Column. Without a key Flutter re-creates the TextField every time
  // the list opens/closes, which drops the IME connection (typing after "@"
  // did nothing until the user clicked the box again).
  final GlobalKey _textFieldKey = GlobalKey(debugLabel: 'chat_input_field');

  @override
  Widget build(BuildContext context) {
    final chatData = ChatData.of(context);
    final currentUser = chatData.currentUser;
    final canPost = widget.chat.canPostMessage(currentUser);
    _canPost = canPost;

    if (!canPost) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.announcement_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              "Only administrators can post in this channel.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
          if (_isReply) _replyMessage(_chat, context, _messageProvider),
          if (_isEdit) _editMessage(_chat, context, _messageProvider),
          if (_voiceUploads > 0)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: Theme.of(context).colorScheme.primary,
            ),
          if (_pickedFiles.isNotEmpty) _pickedFilesView(),
          ListenableBuilder(
            listenable: _voice,
            builder: (context, _) {
              // Auto-stop at the maximum length.
              if (_voice.reachedMax && !_voiceFinishing) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _finishVoice(send: true);
                });
              }
              return Row(
            children: [
              if (!_voiceActive)
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () async {
                  // var result = await Sheet.showSheet(context,
                  //     widget: const PickOption(uploadDoc: true), size: 0.3);
                  // if (result != null) {
                  //   if (result == 1) {
                  //     var image = await PickImage.captureImage();
                  //     if (image != null) {
                  //       _pickedFiles.add(image);
                  //       setState(() {});
                  //     }
                  //   } else if (result == 2) {
                  //     var images = await PickImage.pickMultipleImages();
                  //     if (images.isNotEmpty) {
                  //       _pickedFiles.addAll(images);
                  //       setState(() {});
                  //     }
                  //   } else {
                  var files = await FilePick.pickFiles(context);
                  if (files != null) {
                    if (files.isNotEmpty) {
                      _pickedFiles.addAll(files);
                      setState(() {});
                    }
                  }
                  //   }
                  // }
                },
              ),
              Expanded(
                child: _voiceActive
                    ? _voiceBar(context)
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showMentionList)
                      KeyedSubtree(
                        key: const ValueKey('mention_list'),
                        child: _mentionList(),
                      ),
                    Container(
                      key: _textFieldKey,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: focusNode,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        
                        minLines: 1,
                        maxLines: 5,
                        // Android keyboards inserting an image.
                        contentInsertionConfiguration:
                            ContentInsertionConfiguration(
                              onContentInserted: _onKeyboardContent,
                            ),
                        // Long-press / right-click menu gets an extra
                        // "Paste image / file" entry (the standard Paste only
                        // handles text).
                        contextMenuBuilder: (context, editableTextState) {
                          final items = [
                            ...editableTextState.contextMenuButtonItems,
                            if (!kIsWeb)
                              ContextMenuButtonItem(
                                label: 'Paste image / file',
                                onPressed: () {
                                  editableTextState.hideToolbar();
                                  _pasteAttachmentsFromClipboard(explicit: true);
                                },
                              ),
                          ];
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: items,
                          );
                        },
                        onChanged: (value) async {
                          setState(() {});
                          // if (value.isNotEmpty) {
                          //   await ChatService.updateTypingOnChat(
                          //     chatId: uid,
                          //     status: true,
                          //   );
                          // } else {
                          //   await ChatService.updateTypingOnChat(
                          //     chatId: uid,
                          //     status: false,
                          //   );
                          // }
                        },
                        onEditingComplete: () async {
                          // await ChatService.updateTypingOnChat(
                          //   chatId: uid,
                          //   status: false,
                          // );
                        },
                        onTapOutside: (event) async {
                          // await ChatService.updateTypingOnChat(
                          //   chatId: uid,
                          //   status: false,
                          // );
                        },
                        decoration: InputDecoration(
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          hintText: "Send a message...",
                          border: InputBorder.none,
                          filled: true,
                          fillColor: AppColors.transparent,
                          suffixIcon: !hasText && _pickedFiles.isEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.image_outlined,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: _pickFiles,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _trailingAction(context),
            ],
          );
            },
          ),
        ],
      );
  }

  List<MentionModel> _recalculateMentions(String text) {
    List<MentionModel> updated = [];

    for (final m in _mentions) {
      final index = text.indexOf('@${m.name}');
      if (index != -1) {
        updated.add(
          MentionModel(
            uid: m.uid,
            name: m.name,
            start: index,
            end: index + m.name.length + 1,
          ),
        );
      }
    }

    return updated;
  }

  Future<void> _sendMessage() async {
    if (!mounted) return;

    final chatData = ChatData.of(context);
    final uid = chatData.uid;

    final message = _controller.text.trim();

    if (_pickedFiles.isEmpty && message.isEmpty) return;

    // Store local copies BEFORE clearing UI
    final pickedFiles = List<PlatformFile>.from(_pickedFiles);

    // Mentions are recalculated for both group chats and one-to-one chats.
    final updatedMentions = _recalculateMentions(message);

    final replyId = _isReply ? _chat?.uid : null;

    // Capture edit state BEFORE clearing the provider. clearMessage() notifies
    // listeners, which resets _isEdit/_chat to false/null; reading them after
    // that made an edit get sent as a brand new message.
    final isEditing = _isEdit;
    final editingMessageId = _chat?.uid ?? '';

    // 🚀 INSTANT UI CLEAR
    _controller.clear();
    _pickedFiles.clear();
    _mentions.clear();

    _messageProvider?.clearMessage();

    if (mounted) {
      setState(() {});
    }

    if (!(isEditing && editingMessageId.isNotEmpty)) {
      // New message: show it in the chat immediately (local previews + upload
      // progress). Uploading and saving continue in the background, and the
      // store also cleans up paste / drop temp copies when it is done.
      PendingMessageStore.instance.send(
        chatId: uid,
        message: message,
        files: pickedFiles,
        participants: widget.chat.participants,
        threadId: widget.threadId,
        replyFor: replyId,
        mentions: updatedMentions,
      );
      return;
    }

    // Editing an existing message keeps the original (awaited) flow.
    try {
      List<FileModel> attachments = [];
      if (pickedFiles.isNotEmpty) {
        attachments = await _uploadFiles(pickedFiles);
      }

      await ChatService.editChatMessage(
        uid: uid,
        chatId: editingMessageId,
        message: message,
        attachments: attachments,
      );
      // Edited existing message: no new-message notification.
    } catch (e) {
      debugPrint("Edit message error: $e");
    } finally {
      // Temp copies made by paste / drop are no longer needed.
      for (final f in pickedFiles) {
        AttachmentIntake.discard(f);
      }
    }
  }

  final imageExtensions = ["png", "jpg", "jpeg", "webp", "bmp", "gif", "tiff"];
  final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
  final audioExtensions = ['mp3', 'wav', 'aac'];
  final docExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'];

  /// Attachments waiting to be sent. Wraps onto new rows (no horizontal
  /// scrolling); only scrolls vertically once there are a lot of files.
  Widget _pickedFilesView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 176),
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_pickedFiles.length, (index) {
                final pf = _pickedFiles[index];
                final ext = pf.name.split('.').last.toLowerCase();
                return SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildFilePreview(pf, ext),
                      Positioned(
                        top: 3,
                        right: 3,
                        child: GestureDetector(
                          onTap: () => _removeFile(index),
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.6),
                            child: Icon(
                              Icons.close,
                              size: 13,
                              color: Theme.of(context).colorScheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview(PlatformFile pf, String ext) {
    if (_kImageExt.contains(ext)) {
      // NOTE: PlatformFile.path throws on web, so check kIsWeb first.
      ImageProvider? provider;
      if (!kIsWeb && pf.path != null) {
        provider = FileImage(File(pf.path!));
      } else if (pf.bytes != null) {
        provider = MemoryImage(pf.bytes!);
      }
      if (provider != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image(
            image: ResizeImage(provider, width: 240),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                _iconPreview(Colors.black45, Icons.image_outlined, ext, pf.name),
          ),
        );
      }
    }

    if (_kVideoExt.contains(ext)) {
      return _iconPreview(Colors.black87, Icons.videocam, ext, pf.name);
    }
    if (_kAudioExt.contains(ext)) {
      return _iconPreview(Colors.teal, Icons.audiotrack, ext, pf.name);
    }
    if (ext == "pdf") {
      return _iconPreview(Colors.red.shade400, Icons.picture_as_pdf, ext, pf.name);
    }
    if (["doc", "docx"].contains(ext)) {
      return _iconPreview(Colors.blue, Icons.description, ext, pf.name);
    }
    if (["xls", "xlsx"].contains(ext)) {
      return _iconPreview(Colors.green, Icons.table_chart, ext, pf.name);
    }
    if (["ppt", "pptx"].contains(ext)) {
      return _iconPreview(Colors.deepOrange, Icons.slideshow, ext, pf.name);
    }
    if (["zip", "rar", "7z"].contains(ext)) {
      return _iconPreview(Colors.grey, Icons.archive, ext, pf.name);
    }
    if (["txt", "csv", "json"].contains(ext)) {
      return _iconPreview(Colors.brown, Icons.notes, ext, pf.name);
    }
    return _iconPreview(Colors.black45, Icons.insert_drive_file, ext, pf.name);
  }

  Widget _iconPreview(Color color, IconData icon, String ext, String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 2),
          Text(
            ext.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Padding _replyMessage(
    MessagesModel? chat,
    BuildContext context,
    MessageProvider? messageProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 70,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.1),
                offset: const Offset(0, -3),
                blurRadius: 6,
                spreadRadius: -1,
              ),
            ],
            color: Theme.of(context).cardTheme.color,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Avatar
                          ((CacheService.getUserByUid(
                                        chat?.senderId ?? '',
                                      )?.profileImageUrl) !=
                                      null &&
                                  (CacheService.getUserByUid(
                                    chat?.senderId ?? '',
                                  )?.profileImageUrl)!.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: CachedNetworkImage(
                                    imageUrl: (CacheService.getUserByUid(
                                      chat?.senderId ?? '',
                                    )?.profileImageUrl)!,
                                    placeholder: (context, url) =>
                                        Shimmer.fromColors(
                                          baseColor: AppColors.grey300,
                                          highlightColor: AppColors.grey100,
                                          child: Container(
                                            color: Theme.of(
                                              context,
                                            ).cardTheme.color,
                                          ),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                    height: 20,
                                    width: 20,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child:
                                      ((CacheService.getUserByUid(
                                                chat?.senderId ?? '',
                                              )?.profileImageUrl) ==
                                              null ||
                                          (CacheService.getUserByUid(
                                            chat?.senderId ?? '',
                                          )?.profileImageUrl)!.isEmpty)
                                      ? const Icon(Iconsax.user, size: 12)
                                      : null,
                                ),

                          const SizedBox(width: 5),
                          // Name
                          Text(
                            CacheService.getUserByUid(
                                  chat?.senderId ?? '',
                                )?.name ??
                                '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Message with ellipsis
                      SizedBox(
                        width: double.infinity, // Force width constraint
                        child: Text(
                          chat?.message ?? '',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: () =>
                      setState(() => messageProvider?.clearMessage()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mentionList() {
    if (_filteredUsers.isEmpty) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          "No users found",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];

          return InkWell(
            onTap: () => _selectMention(user),
            // Prevent this tile from ever taking keyboard focus itself,
            // so tapping it never unfocuses the message text field —
            // the user can keep tagging or typing without interruption.
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  /// Avatar
                  _buildMentionAvatar(user),

                  const SizedBox(width: 10),

                  /// Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _highlightName(user.name),
                        const SizedBox(height: 2),
                        Text(
                          "Tap to mention",
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  /// Optional icon
                  Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMentionAvatar(MentionModel user) {
    if (user.image != null && user.image!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: CachedNetworkImage(
          imageUrl: user.image!,
          height: 36,
          width: 36,
          fit: BoxFit.cover,
          placeholder: (_, _) => CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (_, _, _) => _initialAvatar(user.name),
        ),
      );
    }

    return _initialAvatar(user.name);
  }

  Widget _initialAvatar(String name) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        name[0].toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _highlightName(String name) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    if (cursorPos < 0) return Text(name);

    final subText = text.substring(0, cursorPos);
    final match = RegExp(r'(?:^|\s)@([a-zA-Z0-9_]*)$').firstMatch(subText);

    if (match == null) return Text(name);

    final query = match.group(1)?.toLowerCase() ?? '';

    if (query.isEmpty) {
      return Text(name, style: const TextStyle(fontWeight: FontWeight.w500));
    }

    final startIndex = name.toLowerCase().indexOf(query);

    if (startIndex == -1) {
      return Text(name);
    }

    final endIndex = startIndex + query.length;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: name.substring(0, startIndex),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          TextSpan(
            text: name.substring(startIndex, endIndex),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: name.substring(endIndex),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Padding _editMessage(
    MessagesModel? chat,
    BuildContext context,
    MessageProvider? messageProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 70,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.1),
                offset: const Offset(0, -3),
                blurRadius: 6,
                spreadRadius: -1,
              ),
            ],
            color: Theme.of(context).cardTheme.color,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "You",
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Message with ellipsis
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          chat?.message ?? '',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: () =>
                      setState(() => messageProvider?.clearMessage()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Voice UI ────────────────────────────────────────────────────────

  /// The slot at the right of the composer: send-message button, mic, or the
  /// send-voice button while a locked recording is running.
  Widget _trailingAction(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Hands-free recording: this button sends the voice message.
    if (_voiceActive && !_voiceHeld) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        child: IconButton(
          tooltip: 'Send voice message',
          icon: Icon(Iconsax.send_2, color: cs.onPrimary, size: 18),
          onPressed: () => _finishVoice(send: true),
        ),
      );
    }

    final showMic = !hasText && _pickedFiles.isEmpty && !_isEdit;
    if (!showMic) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        child: IconButton(
          icon: Icon(Iconsax.send_2, color: cs.onPrimary, size: 18),
          onPressed: () async => await _sendMessage(),
        ),
      );
    }

    final touch = _isTouchPlatform();
    return GestureDetector(
      key: const ValueKey('voice_mic_button'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _beginVoice(held: false),
      // Press-and-hold is touch-only; with a mouse a slow click would
      // otherwise start (and instantly discard) a hold recording.
      onLongPressStart: touch ? (_) => _beginVoice(held: true) : null,
      onLongPressMoveUpdate: touch ? _onVoiceMove : null,
      onLongPressEnd: touch ? (_) => _onVoiceHoldEnd() : null,
      onLongPressCancel: touch
          ? () {
              if (_voiceHeld) _finishVoice(send: false);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedScale(
          scale: _voiceHeld ? 1.7 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _voiceHeld
                  ? (_voiceWillCancel ? cs.outline : AppColors.danger)
                  : cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Tooltip(
              message: touch ? 'Hold to record' : 'Record voice message',
              child: Icon(
                Icons.mic_rounded,
                size: 22,
                color: _voiceHeld ? Colors.white : cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Replaces the text field while a voice message is being recorded.
  Widget _voiceBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final paused = _voice.isPaused;

    // Blinking red dot (steady when paused).
    final blinkOn = paused || (_voice.elapsed.inMilliseconds ~/ 500) % 2 == 0;

    final timer = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: blinkOn ? 1 : 0.25,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: paused ? cs.outline : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatVoiceDuration(_voice.elapsed),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    Widget middle;
    if (_voiceHeld) {
      // Press-and-hold: show the slide-to-cancel hint.
      final fade = (1 - (_voiceDragDx.abs() / _cancelDistance)).clamp(0.2, 1.0);
      middle = Expanded(
        child: Transform.translate(
          offset: Offset(_voiceDragDx / 2, 0),
          child: Opacity(
            opacity: fade,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_left, size: 18, color: cs.onSurfaceVariant),
                Flexible(
                  child: Text(
                    _voiceWillCancel ? 'Release to cancel' : 'Slide to cancel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _voiceWillCancel
                          ? AppColors.danger
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: cs.onSurfaceVariant,
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 15,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Locked / desktop: live waveform.
      middle = Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 28,
            child: CustomPaint(
              painter: _WaveformPainter(
                levels: _voice.liveLevels,
                progress: 1,
                activeColor: paused ? cs.outline : cs.primary,
                inactiveColor: cs.outline,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          if (!_voiceHeld)
            IconButton(
              tooltip: 'Discard',
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () => _finishVoice(send: false),
            )
          else
            const SizedBox(width: 8),
          timer,
          middle,
          if (!_voiceHeld)
            IconButton(
              tooltip: paused ? 'Resume' : 'Pause',
              icon: Icon(
                paused ? Icons.mic_rounded : Icons.pause_rounded,
                color: paused ? AppColors.danger : cs.onSurfaceVariant,
              ),
              onPressed: paused ? _voice.resume : _voice.pause,
            ),
        ],
      ),
    );
  }
}