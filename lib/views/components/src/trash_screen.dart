import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/models/src/trash_model.dart';
import '/theme/theme.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

// TrashColors removed in favor of Theme.of(context)

class _TrashScreenState extends State<TrashScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _vScrollController = ScrollController();
  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  bool _selectionMode = false;
  bool _isProcessing = false;
  final Set<String> _selectedIds = {};
  QuerySnapshot? _lastSnapshot;

  Query<Map<String, dynamic>>? _trashRef;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init();

    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final cid = await Spdb.getCid();
    final uid = await Spdb.getUid();
    debugPrint('Trash uid: $uid');

    final ref = _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.trash.name)
        .where('deletedBy', isEqualTo: uid)
        .orderBy('deletedAt', descending: true);

    if (!mounted) return;

    setState(() {
      _trashRef = ref;
    });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectionMode(String id) {
    setState(() {
      if (!_selectionMode) {
        _selectionMode = true;
        _selectedIds.clear();
        _selectedIds.add(id);
      } else {
        _toggleItem(id);
      }
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _restoreSingle(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirm = await _confirmRestore(count: 1);
    if (!confirm) return;

    try {
      setState(() => _isProcessing = true);

      await _restoreDoc(doc);

      if (mounted) {
        FlushBar.show(context, 'Item restored');
      }
    } catch (e) {
      if (mounted) {
        FlushBar.show(context, 'Restore failed: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreSelected() async {
    if (_lastSnapshot == null || _selectedIds.isEmpty) return;

    final docs = _lastSnapshot!.docs
        .where((d) => _selectedIds.contains(d.id))
        .toList();

    final confirm = await _confirmRestore(count: docs.length);
    if (!confirm) return;

    setState(() => _isProcessing = true);

    try {
      for (final doc in docs) {
        await _restoreDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
      }

      if (mounted) {
        FlushBar.show(context, 'Restored ${docs.length} item(s)');
      }

      _clearSelection();
    } catch (e) {
      if (mounted) {
        FlushBar.show(context, 'Restore failed: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreDoc(
    DocumentSnapshot<Map<String, dynamic>> trashDoc,
  ) async {
    final data = trashDoc.data() ?? {};

    final originalPath = data['originalPath'] as String? ?? '';
    final canRestoreTo = data['canRestoreTo'] as String? ?? originalPath;

    if (canRestoreTo.isEmpty) {
      throw Exception('Missing original path for restore');
    }

    final innerData = (data['data'] ?? {}) as Map<String, dynamic>;

    final originalDocRef = _firestore.doc(canRestoreTo);

    final batch = _firestore.batch();
    batch.set(originalDocRef, innerData, SetOptions(merge: false));
    batch.delete(trashDoc.reference);

    await batch.commit();
  }

  Future<bool> _confirmRestore({required int count}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Restore Item",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            count == 1
                ? "Are you sure you want to restore this item?"
                : "Are you sure you want to restore $count items?",
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.restore, size: 16),
              label: const Text("Restore"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _groupByDay(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final map = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final now = DateTime.now();

    for (final doc in docs) {
      final data = doc.data();
      final ts = data['deletedAt'];

      DateTime dt = now;
      if (ts is Timestamp) dt = ts.toDate();

      final diff = DateTime(
        dt.year,
        dt.month,
        dt.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;

      String label;
      if (diff == 0) {
        label = 'Today';
      } else if (diff == -1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('dd MMM yyyy').format(dt);
      }
      map.putIfAbsent(label, () => []).add(doc);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_trashRef == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildHeader(context),
            const Expanded(child: WaitingLoading()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Back(color: AppColors.white),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.trash,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Trash",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Restore items deleted in the last 30 days",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectionMode)
                IconButton(
                  tooltip: 'Clear selection',
                  icon: const Icon(Icons.close, color: AppColors.white),
                  onPressed: _isProcessing ? null : _clearSelection,
                ),
              IconButton(
                tooltip: "Refresh",
                icon: const Icon(
                  Iconsax.refresh,
                  size: 18,
                  color: AppColors.white,
                ),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search deleted items',
                hintStyle: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.grey500),
                prefixIcon: const Icon(
                  Iconsax.search_normal_1,
                  size: 16,
                  color: AppColors.grey500,
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        splashRadius: 16,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.grey500,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(12)
                ),
                
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(12)
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(12)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _trashRef!.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return WaitingLoading();
            }

            if (!snapshot.hasData) {
              return WaitingLoading();
            }

            final docs = snapshot.data!.docs;

            final filteredDocs = docs.where((doc) {
              if (_search.isEmpty) return true;

              final data = doc.data();
              final inner = (data['data'] ?? {}) as Map<String, dynamic>;

              final title = inner['title']?.toString().toLowerCase() ?? '';
              final name = inner['name']?.toString().toLowerCase() ?? '';
              final path = (data['originalPath'] ?? '')
                  .toString()
                  .toLowerCase();

              return title.contains(_search) ||
                  name.contains(_search) ||
                  path.contains(_search);
            }).toList();

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.trash,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _search.isEmpty ? "No deleted items" : "No results found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _search.isEmpty
                          ? "Items you delete will appear here"
                          : "Try a different search term",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            _lastSnapshot = snapshot.data;

            final grouped = _groupByDay(filteredDocs);

            return RefreshIndicator(
              onRefresh: () async {},
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Scrollbar(
                      controller: _vScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: ListView(
                      controller:_vScrollController,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: grouped.entries.map((entry) {
                                return _buildSection(entry.key, entry.value);
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        if (_isProcessing)
          Container(
            color: AppColors.black.withValues(alpha: 0.2),
            child: WaitingLoading(),
          ),

        if (_selectionMode)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  /// Selected Count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${_selectedIds.length} selected",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text("Restore"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: _selectedIds.isEmpty || _isProcessing
                          ? null
                          : _restoreSelected,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSection(String label, List docs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 14;
              const double minCardWidth = 320;

              final double width = constraints.maxWidth;
              int columns = (width / (minCardWidth + spacing)).floor();
              columns = columns.clamp(1, 3);

              final double itemWidth =
                  (width - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: docs
                    .map(
                      (doc) => SizedBox(
                        width: itemWidth,
                        child: _buildTrashCard(doc),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final trash = TrashModel.fromMap(doc.data());
    final id = doc.id;

    final innerData = trash.data;
    final collection = trash.collection;

    String title =
        innerData['title']?.toString() ??
        innerData['name']?.toString() ??
        'Untitled';

    title = "${title.decrypt} ";

    final time = _timeAgo(trash.deletedAt);
    final selected = _selectedIds.contains(id);

    return GestureDetector(
      onTap: () {
        if (_selectionMode) {
          _toggleItem(id);
        } else {
          _toggleSelectionMode(id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildIcon(collection),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          collection.capitalizeFirst,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _timeBadge(time),
                ],
              ),

              const SizedBox(height: 10),

              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.folder,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),

                        Expanded(
                          child: Text(
                            trash.canRestoreTo,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  if (_selectionMode)
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    )
                  else
                    TextButton.icon(
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text("Restore"),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.success,
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () => _restoreSingle(doc),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeBadge(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        time,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildIcon(String collection) {
    IconData icon;

    switch (collection.toLowerCase()) {
      case 'tasks':
        icon = Iconsax.task;
        break;
      case 'users':
        icon = Iconsax.user;
        break;
      case 'files':
        icon = Iconsax.document;
        break;
      default:
        icon = Iconsax.archive;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.error),
    );
  }

  // Widget _buildHeaderSearch() {
  //   return Column(
  //     children: [
  //       Container(color: TrashColors.border, height: 1),
  //       Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //         child: Material(
  //           borderRadius: BorderRadius.circular(12),
  //           color: TrashColors.background,
  //           child: TextField(
  //             controller: _searchController,
  //             decoration: const InputDecoration(
  //               prefixIcon: Icon(Icons.search, size: 18),
  //               hintText: 'Search deleted items...',
  //               border: InputBorder.none,
  //               contentPadding: EdgeInsets.symmetric(vertical: 14),
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
}
