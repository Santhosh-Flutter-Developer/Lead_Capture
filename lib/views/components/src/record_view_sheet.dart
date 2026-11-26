import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/views/components/src/sheet.dart';
import '/views/ui/src/general_dialog.dart';

/// One label / value row shown in a [RecordViewSection].
class RecordViewField {
  final String label;
  final String value;
  const RecordViewField(this.label, this.value);
}

/// A titled card of read-only fields.
class RecordViewSection {
  final String title;
  final List<RecordViewField> fields;
  const RecordViewSection(this.title, this.fields);
}

/// Generic read-only "view" drawer used by the table views that have no
/// dedicated detail screen (opened with the eye icon in the Action column).
///
/// Pops with `'edit'` when the Edit button is pressed so the caller can open
/// its own edit form.
class RecordViewSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;

  /// Optional highlighted block under the header (summary / progress card).
  final Widget? summary;
  final List<RecordViewSection> sections;

  /// Extra widgets shown after the sections (lists, allocations, ...).
  final List<Widget> extra;

  /// Edit button label; the button is hidden when [canEdit] is false.
  final bool canEdit;
  final String editLabel;

  const RecordViewSheet({
    super.key,
    required this.title,
    this.subtitle = '',
    this.icon = Icons.visibility_outlined,
    this.badge,
    this.summary,
    this.sections = const [],
    this.extra = const [],
    this.canEdit = false,
    this.editLabel = 'Edit',
  });

  /// Opens the drawer (bottom sheet on mobile / narrow screens, right-side
  /// drawer on wide screens). Returns `'edit'` when Edit was pressed.
  static Future<dynamic> show(BuildContext context, RecordViewSheet sheet) {
    final width = MediaQuery.of(context).size.width;
    if (kIsMobile || width < 900) {
      return Sheet.showSheet(context, widget: sheet);
    }
    return GeneralDialog.showRTLSheet(context, sheet);
  }

  static String dash(String? v) =>
      (v == null || v.trim().isEmpty) ? '-' : v.trim();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (summary != null) ...[summary!, const SizedBox(height: 16)],
                  for (final s in sections) ...[
                    _sectionCard(context, s),
                    const SizedBox(height: 16),
                  ],
                  ...extra,
                ],
              ),
            ),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 14,
        8,
        14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (badge != null && badge!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, RecordViewSection s) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 420 ? 2 : 1;
              final w = (c.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  for (final f in s.fields)
                    SizedBox(
                      width: w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dash(f.value),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close'),
          ),
          if (canEdit) ...[
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('edit'),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(editLabel),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}