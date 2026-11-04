import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a task / ticket comment. Comments are stored as Markdown, so old plain-text
/// comments keep working and formatted ones show bold / lists / links etc.
class RichCommentText extends StatelessWidget {
  final String data;
  const RichCommentText({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: theme.colorScheme.onSurface,
    );
    return MarkdownBody(
      data: data,
      softLineBreak: true,
      onTapLink: (text, href, title) {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: base,
        listBullet: base,
        a: base.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        strong: base.copyWith(fontWeight: FontWeight.w800),
        em: base.copyWith(fontStyle: FontStyle.italic),
        del: base.copyWith(decoration: TextDecoration.lineThrough),
        code: base.copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: base.copyWith(color: theme.colorScheme.onSurfaceVariant),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
        ),
      ),
    );
  }
}

/// Comment box with a formatting toolbar (bold, italic, strike, code, lists,
/// quote, link) and a Write / Preview switch. Output is Markdown text in
/// [controller].
///
/// Shortcuts: Ctrl/Cmd+B bold, Ctrl/Cmd+I italic, Ctrl/Cmd+Enter send.
class RichCommentEditor extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const RichCommentEditor({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  State<RichCommentEditor> createState() => _RichCommentEditorState();
}

class _RichCommentEditorState extends State<RichCommentEditor> {
  final FocusNode _focus = FocusNode();
  bool _preview = false;

  TextEditingController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    // After a comment is sent the box is cleared: go back to writing.
    if (_preview && _c.text.isEmpty) {
      setState(() => _preview = false);
    } else {
      setState(() {});
    }
  }

  bool get _canSend => _c.text.trim().isNotEmpty && !widget.isSending;

  void _send() {
    if (_canSend) widget.onSend();
  }

  // ----------------------------- formatting ------------------------------

  TextSelection get _sel {
    final s = _c.selection;
    if (s.isValid && s.start >= 0) return s;
    return TextSelection.collapsed(offset: _c.text.length);
  }

  /// Wraps the selection with [left]/[right]; wraps again = unwraps.
  void _wrap(String left, String right, {String placeholder = 'text'}) {
    final text = _c.text;
    final sel = _sel;
    final start = sel.start;
    final end = sel.end;

    final alreadyWrapped =
        start >= left.length &&
        end + right.length <= text.length &&
        text.substring(start - left.length, start) == left &&
        text.substring(end, end + right.length) == right;

    if (alreadyWrapped) {
      final inner = text.substring(start, end);
      _c.value = TextEditingValue(
        text: text.replaceRange(start - left.length, end + right.length, inner),
        selection: TextSelection(
          baseOffset: start - left.length,
          extentOffset: start - left.length + inner.length,
        ),
      );
    } else {
      final inner = start == end ? placeholder : text.substring(start, end);
      _c.value = TextEditingValue(
        text: text.replaceRange(start, end, '$left$inner$right'),
        selection: TextSelection(
          baseOffset: start + left.length,
          extentOffset: start + left.length + inner.length,
        ),
      );
    }
    _focus.requestFocus();
  }

  /// Adds (or, if every line already has it, removes) a line prefix.
  void _prefixLines(RegExp existing, String Function(int index) make) {
    final text = _c.text;
    final sel = _sel;
    final lineStart = sel.start == 0
        ? 0
        : text.lastIndexOf('\n', sel.start - 1) + 1;
    var lineEnd = text.indexOf('\n', sel.end);
    if (lineEnd == -1) lineEnd = text.length;

    final lines = text.substring(lineStart, lineEnd).split('\n');
    final allHave = lines.every((l) => existing.hasMatch(l));
    final changed = [
      for (var i = 0; i < lines.length; i++)
        allHave ? lines[i].replaceFirst(existing, '') : make(i) + lines[i],
    ].join('\n');

    _c.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, changed),
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + changed.length,
      ),
    );
    _focus.requestFocus();
  }

  void _link() {
    final text = _c.text;
    final sel = _sel;
    final label = sel.start == sel.end
        ? 'link text'
        : text.substring(sel.start, sel.end);
    const url = 'https://';
    final insert = '[$label]($url)';
    final urlStart = sel.start + label.length + 3; // "[" + label + "]("
    _c.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, insert),
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + url.length,
      ),
    );
    _focus.requestFocus();
  }

  // ------------------------------- UI ------------------------------------

  Widget _tool(IconData icon, String tip, VoidCallback onTap) {
    return IconButton(
      tooltip: tip,
      onPressed: _preview ? null : onTap,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- toolbar ----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _tool(
                          Icons.format_bold,
                          'Bold (Ctrl+B)',
                          () => _wrap('**', '**'),
                        ),
                        _tool(
                          Icons.format_italic,
                          'Italic (Ctrl+I)',
                          () => _wrap('*', '*'),
                        ),
                        _tool(
                          Icons.strikethrough_s,
                          'Strikethrough',
                          () => _wrap('~~', '~~'),
                        ),
                        _tool(Icons.code, 'Code', () => _wrap('`', '`')),
                        Container(
                          width: 1,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: scheme.outlineVariant,
                        ),
                        _tool(
                          Icons.format_list_bulleted,
                          'Bulleted list',
                          () => _prefixLines(RegExp(r'^[-*] '), (_) => '- '),
                        ),
                        _tool(
                          Icons.format_list_numbered,
                          'Numbered list',
                          () => _prefixLines(
                            RegExp(r'^\d+\. '),
                            (i) => '${i + 1}. ',
                          ),
                        ),
                        _tool(
                          Icons.format_quote,
                          'Quote',
                          () => _prefixLines(RegExp(r'^> '), (_) => '> '),
                        ),
                        _tool(Icons.link, 'Link', _link),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _c.text.trim().isEmpty && !_preview
                      ? null
                      : () => setState(() => _preview = !_preview),
                  icon: Icon(
                    _preview ? Icons.edit_outlined : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(_preview ? 'Write' : 'Preview'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

          // ---- editor / preview ----
          if (_preview)
            Container(
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.all(14),
              child: RichCommentText(data: _c.text),
            )
          else
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                    () => _wrap('**', '**'),
                const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () =>
                    _wrap('**', '**'),
                const SingleActivator(LogicalKeyboardKey.keyI, control: true):
                    () => _wrap('*', '*'),
                const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () =>
                    _wrap('*', '*'),
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  control: true,
                ): _send,
                const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                    _send,
              },
              child: TextField(
                controller: _c,
                focusNode: _focus,
                minLines: 3,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Add a progress update...',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),

          // ---- footer ----
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ctrl+Enter to post',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                widget.isSending
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _canSend ? _send : null,
                        icon: const Icon(Iconsax.send_1, size: 16),
                        label: const Text('Post'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}