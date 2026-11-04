// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '/theme/theme.dart';

/// CustomSearchableDropdown supports single-select and multi-select modes.
/// - For single-select: provide `initialValue` and `onChanged: (T?)`.
/// - For multi-select: set `multiSelect: true`, provide `initialValues` and `onChangedList`.
class CustomSearchableDropdown<T> extends StatefulWidget {
  final List<T> items;
  final T? initialValue;
  final List<T>? initialValues; // for multi-select
  final ValueChanged<T?>? onChanged; // single select callback
  final ValueChanged<List<T>>? onChangedList; // multi select callback
  final bool multiSelect;
  final String Function(T)? itemAsString;
  final String hintText;
  final double maxPanelHeight;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget? emptyWidget;
  final bool showDoneButton; // show done to confirm selections in multi-select
  final bool showClearButton; // show an "x" to clear the current selection (single-select only)

  const CustomSearchableDropdown({
    super.key,
    required this.items,
    this.initialValue,
    this.initialValues,
    this.onChanged,
    this.onChangedList,
    this.multiSelect = false,
    this.itemAsString,
    this.hintText = 'Select',
    this.maxPanelHeight = 280,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.emptyWidget,
    this.showDoneButton = true,
    this.showClearButton = true,
  });

  @override
  State<CustomSearchableDropdown<T>> createState() =>
      _CustomSearchableDropdownState<T>();
}

class _CustomSearchableDropdownState<T>
    extends State<CustomSearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _panelFocus = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late List<T> _filtered;
  T? _selected;
  final List<T> _selectedList = [];
  int _highlightIndex = -1;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _filtered = List<T>.from(widget.items);

    if (widget.multiSelect && widget.initialValues != null) {
      _selectedList.addAll(widget.initialValues!);
    }

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant CustomSearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _filtered = List<T>.from(widget.items);
      _overlayEntry?.markNeedsBuild();
    }
    if (widget.initialValue != oldWidget.initialValue) {
      _selected = widget.initialValue;
      _overlayEntry?.markNeedsBuild();
      setState(() {});
    }
    if (widget.multiSelect && widget.initialValues != oldWidget.initialValues) {
      _selectedList
        ..clear()
        ..addAll(widget.initialValues ?? []);
      _overlayEntry?.markNeedsBuild();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _searchFocus.dispose();
    _panelFocus.dispose();
    // Remove immediately (not via the delayed _removeOverlay() below) since
    // the widget is going away right now regardless of any in-flight ripple.
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _open() {
    if (_isOpen) return;
    _filtered = List<T>.from(widget.items);
    _highlightIndex = widget.multiSelect
        ? (_selectedList.isNotEmpty
              ? widget.items.indexOf(_selectedList.first)
              : -1)
        : (_selected != null ? _filtered.indexOf(_selected as T) : -1);
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _panelFocus.requestFocus();
        _searchFocus.requestFocus();
        _searchController.selection = TextSelection.collapsed(
          offset: _searchController.text.length,
        );
      }
    });
  }

  void _close({bool returnFocus = true, bool notify = true}) {
    if (!_isOpen) return;
    _removeOverlay();
    setState(() => _isOpen = false);
    if (returnFocus) {
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }

    if (widget.multiSelect && notify) {
      widget.onChangedList?.call(List<T>.from(_selectedList));
    }
  }

  void _removeOverlay() {
    // A single post-frame callback isn't long enough: Material ink-splash
    // effects on the tapped item (ListTile/InkWell) run over many frames via
    // their own AnimationController/Ticker (Flutter's default ripple fade is
    // ~225-300ms). Ripping the OverlayEntry's RenderObject tree out of the
    // Overlay while that ticker is still firing on it is what produced the
    // red screen: "Assertion failed ... debugNeedsLayout is not true".
    // Waiting long enough for the ripple to finish before removing avoids
    // this entirely. entry.remove() is also guarded because, if this dropdown
    // is closed and reopened quickly, the entry may already have been
    // removed/replaced by the time this timer fires.
    final entry = _overlayEntry;
    _overlayEntry = null;
    if (entry == null) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        entry.remove();
      } catch (_) {
        // Already removed (e.g. dispose() ran first) — safe to ignore.
      }
    });
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _onItemSelectedSingle(T item) {
    widget.onChanged?.call(item);
    setState(() {
      _selected = item;
    });
    _close();
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
    });
    widget.onChanged?.call(null);
  }

  void _onItemToggledMulti(T item) {
    final already = _selectedList.indexWhere((e) => e == item) >= 0;
    setState(() {
      if (already) {
        _selectedList.removeWhere((e) => e == item);
      } else {
        _selectedList.add(item);
      }
    });

    // update overlay immediately
    _overlayEntry?.markNeedsBuild();
    // do not close on multi-select tap; user will press Done (or you can set notify immediate)
    // optionally notify live changes:
    // widget.onChangedList?.call(List<T>.from(_selectedList));
  }

  /// Called from controller listener - this filters items and calls setState so
  /// the panel updates as the user types (and also when cleared programmatically).
  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<T>.from(widget.items);
      } else {
        _filtered = widget.items.where((it) {
          final s = (widget.itemAsString?.call(it) ?? it.toString())
              .toLowerCase();
          return s.contains(q);
        }).toList();
      }
      if (_filtered.isEmpty) {
        _highlightIndex = -1;
      } else {
        _highlightIndex = (_highlightIndex >= _filtered.length)
            ? _filtered.length - 1
            : (_highlightIndex < 0 ? 0 : _highlightIndex);
      }
    });

    if (_overlayEntry != null) _overlayEntry!.markNeedsBuild();
  }

  OverlayEntry _createOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final globalTopLeft = renderBox.localToGlobal(Offset.zero);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final topPadding = media.padding.top;
    const verticalMargin = 8.0;

    final availableBelow =
        screenHeight - (globalTopLeft.dy + size.height) - verticalMargin;
    final availableAbove = globalTopLeft.dy - topPadding - verticalMargin;

    final preferBelow =
        availableBelow >= math.min(widget.maxPanelHeight, availableAbove);

    final double panelHeight = preferBelow
        ? math.min(widget.maxPanelHeight, availableBelow)
        : math.min(widget.maxPanelHeight, availableAbove);

    final double constrainedPanelHeight = panelHeight > 0
        ? panelHeight
        : math.min(
            widget.maxPanelHeight,
            screenHeight - topPadding - verticalMargin * 2,
          );

    final isAbove = !preferBelow;

    final targetAnchor = isAbove ? Alignment.topLeft : Alignment.bottomLeft;
    final followerAnchor = isAbove ? Alignment.bottomLeft : Alignment.topLeft;
    final double gap = 6.0;

    return OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: GestureDetector(
            onTap: () => _close(returnFocus: false, notify: widget.multiSelect),
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  targetAnchor: targetAnchor,
                  followerAnchor: followerAnchor,
                  offset: isAbove ? Offset(0, -gap) : Offset(0, gap),
                  child: Material(
                    elevation: 6,
                    borderRadius: widget.borderRadius,
                    child: SizedBox(
                      width: size.width,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constrainedPanelHeight,
                          minWidth: size.width,
                        ),
                        child: RawKeyboardListener(
                          focusNode: _panelFocus,
                          onKey: (RawKeyEvent event) {
                            if (event is RawKeyDownEvent) {
                              final key = event.logicalKey;
                              if (key == LogicalKeyboardKey.escape) {
                                _close();
                              } else if (key == LogicalKeyboardKey.arrowDown) {
                                setState(() {
                                  if (_filtered.isNotEmpty) {
                                    _highlightIndex =
                                        (_highlightIndex + 1) %
                                        _filtered.length;
                                  }
                                });
                              } else if (key == LogicalKeyboardKey.arrowUp) {
                                setState(() {
                                  if (_filtered.isNotEmpty) {
                                    _highlightIndex = _highlightIndex <= 0
                                        ? _filtered.length - 1
                                        : _highlightIndex - 1;
                                  }
                                });
                              } else if (key == LogicalKeyboardKey.enter) {
                                if (_highlightIndex >= 0 &&
                                    _highlightIndex < _filtered.length) {
                                  final item = _filtered[_highlightIndex];
                                  if (widget.multiSelect) {
                                    _onItemToggledMulti(item);
                                  } else {
                                    _onItemSelectedSingle(item);
                                  }
                                }
                              }
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Search field
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: SizedBox(
                                  height: 36, // CONTROL OVERALL HEIGHT
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocus,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall, // SMALLER TEXT
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Search',
                                      hintStyle: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8, // 👈 REDUCES HEIGHT
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      // suffixIcon: _searchController.text.isEmpty
                                      //     ? null
                                      //     : IconButton(
                                      //         padding: EdgeInsets.zero,
                                      //         constraints:
                                      //             const BoxConstraints(),
                                      //         icon: const Icon(
                                      //           Icons.clear,
                                      //           size: 16,
                                      //         ),
                                      //         onPressed: () {
                                      //           _searchController.clear();
                                      //           _overlayEntry?.markNeedsBuild();
                                      //         },
                                      //       ),
                                    ),
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) {
                                      if (_filtered.isNotEmpty) {
                                        final item = _filtered[0];
                                        if (widget.multiSelect) {
                                          _onItemToggledMulti(item);
                                        } else {
                                          _onItemSelectedSingle(item);
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),

                              // list / empty
                              if (_filtered.isEmpty)
                                widget.emptyWidget ??
                                    Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No items found.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    )
                              else
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filtered.length,
                                    itemBuilder: (context, index) {
                                      final item = _filtered[index];
                                      final label =
                                          widget.itemAsString?.call(item) ??
                                          item.toString();
                                      final isHighlighted =
                                          index == _highlightIndex;
                                      final isSelectedSingle =
                                          !widget.multiSelect &&
                                          item == _selected;
                                      final isSelectedMulti =
                                          widget.multiSelect &&
                                          _selectedList.indexWhere(
                                                (e) => e == item,
                                              ) >=
                                              0;

                                      return InkWell(
                                        onTap: () {
                                          if (widget.multiSelect) {
                                            _onItemToggledMulti(item);
                                          } else {
                                            _onItemSelectedSingle(item);
                                          }
                                        },
                                        child: Container(
                                          color: isHighlighted
                                              ? theme.colorScheme.primary
                                                    .withValues(alpha: 0.12)
                                              : null,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  label,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              ),
                                              if (isSelectedSingle ||
                                                  isSelectedMulti)
                                                Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color:
                                                      theme.colorScheme.primary,
                                                )
                                              else if (widget.multiSelect)
                                                const SizedBox(width: 18),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              // Done / actions for multi-select
                              if (widget.multiSelect && widget.showDoneButton)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            // cancel -> close without notifying (use notify false)
                                            _close(
                                              returnFocus: true,
                                              notify: false,
                                            );
                                          },
                                          child: Text(
                                            'Cancel',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                          ),
                                          onPressed: () {
                                            widget.onChangedList?.call(
                                              List<T>.from(_selectedList),
                                            );

                                            _close(
                                              returnFocus: true,
                                              notify: false,
                                            );
                                          },
                                          child: Text(
                                            'Done',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
        _toggle();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        if (!_isOpen) {
          _open();
        } else {
          _panelFocus.requestFocus();
          _searchFocus.requestFocus();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildActivatorContent(String? displayText) {
    if (widget.multiSelect) {
      if (_selectedList.isEmpty) {
        return Text(
          displayText ?? widget.hintText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: displayText == null
                ? Theme.of(context).hintColor
                : Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        );
      }

      // show small chips, or a compact summary if too many
      const maxChipsToShow = 3;
      final chips = _selectedList.take(maxChipsToShow).map((it) {
        final label = widget.itemAsString?.call(it) ?? it.toString();
        return Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList();

      final remaining = _selectedList.length - chips.length;
      return Row(
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          if (remaining > 0)
            Text(
              '+$remaining',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    } else {
      return Text(
        displayText ?? widget.hintText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: displayText == null
              ? Theme.of(context).hintColor
              : Theme.of(context).colorScheme.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _selected != null
        ? (widget.itemAsString?.call(_selected as T) ?? _selected.toString())
        : null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        focusNode: _focusNode,
        onKey: _handleKeyEvent,
        onFocusChange: (hasFocus) {
          if (mounted) setState(() {});
          if (!hasFocus && _isOpen) {
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted &&
                  !_searchFocus.hasFocus &&
                  !_panelFocus.hasFocus &&
                  !_focusNode.hasFocus) {
                _close(returnFocus: false, notify: widget.multiSelect);
              }
            });
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusNode.requestFocus();
            _toggle();
          },
          child: Container(
            padding: widget.padding,
            height: 33,
            decoration: BoxDecoration(
              border: Border.all(
                color: _focusNode.hasFocus
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: _focusNode.hasFocus ? 2 : 1,
              ),
              borderRadius: widget.borderRadius,
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                Expanded(child: _buildActivatorContent(displayText)),
                if (!widget.multiSelect &&
                    widget.showClearButton &&
                    _selected != null) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _clearSelection,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(Icons.clear, size: 16, color: Colors.grey),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(
                  _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A searchable dropdown that loads its items from a [Future].
/// Supports both single-select and multi-select modes with a professional UI.
class CustomFutureSearchableDropdown<T> extends StatefulWidget {
  final Future<List<T>> Function() asyncItems;
  final T? initialValue;
  final List<T>? initialValues; // For multi-select
  final ValueChanged<T?>? onChanged;
  final ValueChanged<List<T>>? onChangedList; // For multi-select
  final bool multiSelect;
  final String Function(T)? itemAsString;
  final String hintText;
  final double maxPanelHeight;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final String? Function(T?)? validator;
  final String? label;
  final bool? isRequired;
  final bool showClearButton; // show an "x" to clear the current selection (single-select only)

  const CustomFutureSearchableDropdown({
    super.key,
    required this.asyncItems,
    this.initialValue,
    this.initialValues,
    this.onChanged,
    this.onChangedList,
    this.multiSelect = false,
    this.itemAsString,
    this.hintText = 'Select',
    this.maxPanelHeight = 280,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.emptyWidget,
    this.loadingWidget,
    this.validator,
    this.label,
    this.isRequired = false,
    this.showClearButton = true,
  });

  @override
  State<CustomFutureSearchableDropdown<T>> createState() =>
      _CustomFutureSearchableDropdownState<T>();
}

class _CustomFutureSearchableDropdownState<T>
    extends State<CustomFutureSearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _panelFocus = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  // OverlayPortal replaces manual OverlayEntry insert()/remove() management.
  // The previous implementation called Overlay.of(context).insert()/remove()
  // imperatively, which tore the overlay's RenderObject subtree out of the
  // tree mid-gesture (e.g. while a tapped ListTile's or "Done" button's ink
  // response was still active), producing:
  // "Assertion failed ... debugNeedsLayout is not true".
  // OverlayPortal is the framework's own replacement for exactly this
  // pattern (used internally by TextField's selection toolbar, Tooltip,
  // etc.) and manages the overlay child's lifecycle safely and
  // declaratively, so there's no remove-while-in-use race to work around.
  final OverlayPortalController _overlayController = OverlayPortalController();
  bool _isOpen = false;
  bool _isLoading = false;

  // Geometry computed once when the dropdown opens (needs the anchor's
  // RenderBox, only reliably available at that point) and reused by
  // _buildOverlayContent() on every rebuild while the portal is shown.
  Size _anchorSize = Size.zero;
  bool _preferBelow = true;
  double _panelHeight = 280;

  List<T> _allItems = [];
  List<T> _filtered = [];
  T? _selected;
  Set<T> _selectedList = {};

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _selectedList = widget.initialValues == null
        ? <T>{}
        : widget.initialValues!.cast<T>().toSet();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant CustomFutureSearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _selected = widget.initialValue;
      setState(() {});
    }
    if (widget.initialValues != oldWidget.initialValues) {
      _selectedList = widget.initialValues == null
          ? <T>{}
          : widget.initialValues!.cast<T>().toSet();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _searchFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (_allItems.isNotEmpty) return;

    setState(() => _isLoading = true);

    try {
      final items = await widget.asyncItems();
      if (mounted) {
        setState(() {
          _allItems = items;
          _filtered = List<T>.from(_allItems);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Computes where the panel should open (above/below the anchor) and how
  /// tall it can be. Needs the anchor's RenderBox, so it must run while the
  /// anchor is still the widget that was tapped (i.e. from _open()), not
  /// lazily inside the overlay builder.
  void _computeOverlayGeometry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final globalTopLeft = renderBox.localToGlobal(Offset.zero);
    final media = MediaQuery.of(context);

    final availableBelow =
        media.size.height - (globalTopLeft.dy + size.height) - 8.0;
    final availableAbove = globalTopLeft.dy - media.padding.top - 8.0;
    final preferBelow =
        availableBelow >= math.min(widget.maxPanelHeight, availableAbove);
    final double panelHeight = preferBelow
        ? math.min(widget.maxPanelHeight, availableBelow)
        : math.min(widget.maxPanelHeight, availableAbove);

    _anchorSize = size;
    _preferBelow = preferBelow;
    _panelHeight = panelHeight;
  }

  void _open() {
    if (_isOpen) return;

    _filtered = List<T>.from(_allItems);
    _computeOverlayGeometry();
    setState(() => _isOpen = true);
    _overlayController.show();

    _loadItems();

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _panelFocus.requestFocus();
        _searchFocus.requestFocus();
      }
    });
  }

  void _close({bool returnFocus = true}) {
    if (!_isOpen) return;
    _overlayController.hide();
    setState(() {
      _isOpen = false;
      _searchController.clear();
    });
    if (returnFocus) _focusNode.requestFocus();
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _onItemSelected(T item) {
    if (widget.multiSelect) {
      setState(() {
        if (!_selectedList.add(item)) {
          _selectedList.remove(item);
        }
      });
      widget.onChangedList?.call(List<T>.from(_selectedList));
    } else {
      widget.onChanged?.call(item);
      setState(() {
        _selected = item;
      });
      _close();
    }
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
    });
    widget.onChanged?.call(null);
  }

  void _clearAllSelections() {
    setState(() {
      _selectedList = <T>{};
    });
    widget.onChangedList?.call(const []);
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<T>.from(_allItems);
      } else {
        _filtered = _allItems.where((it) {
          final s = (widget.itemAsString?.call(it) ?? it.toString())
              .toLowerCase();
          return s.contains(q);
        }).toList();
      }
    });
  }

  Widget _buildOverlayContent(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _close(returnFocus: false),
          behavior: HitTestBehavior.translucent,
          child: Container(color: Colors.transparent),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: _preferBelow ? Alignment.bottomLeft : Alignment.topLeft,
          followerAnchor: _preferBelow
              ? Alignment.topLeft
              : Alignment.bottomLeft,
          offset: Offset(0, _preferBelow ? 6.0 : -6.0),
          child: Material(
            elevation: 8,
            borderRadius: widget.borderRadius,
            child: Container(
              width: _anchorSize.width,
              constraints: BoxConstraints(maxHeight: _panelHeight),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: widget.borderRadius,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        style: Theme.of(context).textTheme.bodySmall,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isLoading)
                    Expanded(
                      child:
                          widget.loadingWidget ??
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                    )
                  else if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child:
                          widget.emptyWidget ?? const Text('No items found'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final label =
                              widget.itemAsString?.call(item) ??
                              item.toString();
                          final bool isSelected = widget.multiSelect
                              ? _selectedList.contains(item)
                              : item == _selected;

                          return ListTile(
                            dense: true,
                            title: Text(
                              label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: Theme.of(context).primaryColor,
                                    size: 18,
                                  )
                                : null,
                            selected: isSelected,
                            onTap: () => _onItemSelected(item),
                          );
                        },
                      ),
                    ),
                  if (widget.multiSelect &&
                      !_isLoading &&
                      _allItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _close(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            "Done",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivatorContent(String? displayText, bool hasSelection) {
    if (widget.multiSelect) {
      if (_selectedList.isEmpty) {
        return Text(
          widget.hintText,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        );
      }

      // Show chips for multi-select to match fixed dropdown UI
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _selectedList.map((item) {
            final label = widget.itemAsString?.call(item) ?? item.toString();
            return Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  GestureDetector(
                    onTap: () {
                      _onItemSelected(item);
                    },
                    child: Icon(Icons.close, size: 15),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    } else {
      return Text(
        displayText ?? widget.hintText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: hasSelection
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).hintColor,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _selected != null
        ? (widget.itemAsString?.call(_selected as T) ?? _selected.toString())
        : null;
    final bool hasSelection = widget.multiSelect
        ? _selectedList.isNotEmpty
        : _selected != null;

    return FormField<T>(
      validator: widget.validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            if (widget.label != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.label!,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.isRequired == true)
                        Text(
                          ' *',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  if (widget.multiSelect && _selectedList.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAllSelections,
                      child: Text(
                        'Clear',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: _buildOverlayContent,
              child: CompositedTransformTarget(
                link: _layerLink,
                child: Focus(
                  focusNode: _focusNode,
                  onFocusChange: (hasFocus) => setState(() {}),
                  child: GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      padding: widget.padding,
                      height: 33, // Match fixed dropdown size
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: _focusNode.hasFocus
                              ? 2
                              : 1, // Match fixed dropdown border logic
                        ),
                        borderRadius: widget.borderRadius,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActivatorContent(
                              displayText,
                              hasSelection,
                            ),
                          ),
                          if (!widget.multiSelect &&
                              widget.showClearButton &&
                              _selected != null) ...[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _clearSelection,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                child: Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Icon(
                            _isOpen
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Error message
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  field.errorText!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
          ],
        );
      },
    );
  }
}