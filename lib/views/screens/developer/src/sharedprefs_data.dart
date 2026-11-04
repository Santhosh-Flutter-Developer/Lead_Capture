import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '/views/views.dart';

class SharedPrefsColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color danger = Color(0xFFEF4444);
}

class SharedprefsData extends StatefulWidget {
  const SharedprefsData({super.key});

  @override
  State<SharedprefsData> createState() => _SharedprefsDataState();
}

class _SharedprefsDataState extends State<SharedprefsData> {
  Map<String, Object?> _prefs = {};
  Map<String, Object?> _filteredPrefs = {};
  bool _loading = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (_loading) return; // prevent multiple taps

    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final Map<String, Object?> map = {};
    for (final k in keys) {
      map[k] = prefs.get(k);
    }

    if (!mounted) return;

    setState(() {
      _prefs = Map.from(map);
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    if (_query.trim().isEmpty) {
      _filteredPrefs = Map.from(_prefs);
    } else {
      final q = _query.toLowerCase();
      _filteredPrefs = Map.fromEntries(
        _prefs.entries.where((e) {
          return e.key.toLowerCase().contains(q) ||
              (e.value?.toString().toLowerCase().contains(q) ?? false);
        }),
      );
    }
  }

  Future<void> _removeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final oldValue = prefs.get(key);
    await prefs.remove(key);
    await _loadAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        content: Text('Removed "$key"', style: const TextStyle(fontSize: 12)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.blueAccent,
          onPressed: () async {
            if (oldValue is String) {
              await prefs.setString(key, oldValue);
            } else if (oldValue is int) {
              await prefs.setInt(key, oldValue);
            } else if (oldValue is bool) {
              await prefs.setBool(key, oldValue);
            } else if (oldValue is double) {
              await prefs.setDouble(key, oldValue);
            } else if (oldValue is List<String>) {
              await prefs.setStringList(key, oldValue);
            }
            await _loadAll();
          },
        ),
      ),
    );
  }

  Future<void> _clearAll() async {
    final should = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Purge Storage?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'This will remove all local SharedPreferences keys. This action is permanent.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (should == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _loadAll();
    }
  }

  Color _getTypeColor(Object? v) {
    if (v is String) return const Color(0xFF3B82F6);
    if (v is int || v is double) return const Color(0xFF8B5CF6);
    if (v is bool) return const Color(0xFF10B981);
    if (v is List) return const Color(0xFFF59E0B);
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _typeLabel(Object? v) {
    if (v is String) return 'STR';
    if (v is int) return 'INT';
    if (v is double) return 'DBL';
    if (v is bool) return 'BOL';
    if (v is List) return 'LST';
    return 'UNK';
  }

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        12,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Back(color: Colors.white),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.data, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Storage Inspector",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Inspect and edit local key-value storage",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _loadAll,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Iconsax.refresh, color: Colors.white, size: 20),
          ),
          IconButton(
            onPressed: _prefs.isEmpty ? null : _clearAll,
            icon: Icon(
              Iconsax.trash,
              color: _prefs.isEmpty
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredPrefs.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 1000;
                return Column(
                  children: [
                    _buildHeaderSearch(items.length, isDesktop),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAll,
                        child: _loading
                            ? const Center(child: WaitingLoading())
                            : items.isEmpty
                            ? Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Scrollbar(
                                  controller: _vScrollController,
                                  thumbVisibility: true,
                                  interactive: true,
                                  trackVisibility: true,
                                  radius: const Radius.circular(8),
                                  thickness: 8,
                                  child: ListView(
                                    controller: _vScrollController,
                                    children: [_buildEmptyState()],
                                  ),
                                ),
                            )
                            : isDesktop
                            ? _buildDesktopGrid(items)
                            : _buildMobileList(items),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSearch(int count, bool isDesktop) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 16,
        vertical: 16,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (s) {
                    setState(() {
                      _query = s;
                      _applyFilter();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search keys or values...",
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Iconsax.search_normal,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$count pairs',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopGrid(List<MapEntry<String, Object?>> items) {
    return Center(
      child: GridView.builder(
        padding: const EdgeInsets.all(40),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 450,
          mainAxisExtent: 200,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final e = items[index];
          return _buildPrefCard(e.key, e.value, isDesktop: true);
        },
      ),
    );
  }

  Widget _buildMobileList(List<MapEntry<String, Object?>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final e = items[index];
        return _buildPrefCard(e.key, e.value, isDesktop: false);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.document_filter,
            size: 48,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            "No preferences found",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefCard(String key, Object? value, {required bool isDesktop}) {
    final typeColor = _getTypeColor(value);
    final valStr = value?.toString() ?? 'null';

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetailDialog(key, value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _typeLabel(value),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: typeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!isDesktop)
                    IconButton(
                      onPressed: () => _removeKey(key),
                      icon: Icon(
                        Iconsax.close_circle,
                        color: Theme.of(context).colorScheme.outlineVariant,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    valStr,
                    maxLines: isDesktop ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              if (isDesktop) const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isDesktop)
                    _actionButton(
                      Iconsax.trash,
                      "Delete",
                      () => _removeKey(key),
                      color: Theme.of(context).colorScheme.error,
                    ),
                  const SizedBox(width: 8),
                  _actionButton(Iconsax.copy, "Copy", () {
                    Clipboard.setData(ClipboardData(text: valStr));
                    FlushBar.show(context, 'Copied to clipboard');
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (isDesktop) return cardContent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(key),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _removeKey(key),
        background: Container(
          decoration: BoxDecoration(
            color: SharedPrefsColors.danger,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Iconsax.trash, color: Colors.white, size: 20),
        ),
        child: cardContent,
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(String key, Object? value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          key,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DATA TYPE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SharedPrefsColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.runtimeType.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "VALUE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SharedPrefsColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: SelectableText(
                    value?.toString() ?? 'null',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: value?.toString() ?? 'null'),
              );
              Navigator.pop(context);
              FlushBar.show(context, 'Copied');
            },
            icon: const Icon(Iconsax.copy, size: 16),
            label: const Text("Copy Value"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
