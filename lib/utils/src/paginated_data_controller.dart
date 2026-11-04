// controllers/paginated_data_controller.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

// Type definitions for the logic you will pass in
typedef FilterLogic<T> = bool Function(T item, String query);
typedef SortLogic<T> =
    int Function(T a, T b, int sortColumn, bool sortAscending);
typedef ItemIdLogic<T> = String Function(T item);

class PaginatedDataController<T> extends ChangeNotifier {
  // --- Configuration (passed in constructor) ---
  final FilterLogic<T> filterLogic;
  final SortLogic<T> sortLogic;
  final ItemIdLogic<T> getItemId;

  // --- Internal State ---
  List<T> _allItems = [];
  List<T> _filteredItems = [];
  List<T> _paginatedItems = [];

  int _sortColumnIndex = 1;
  bool _sortAscending = true;
  int _currentPage = 1;
  int _rowsPerPage;
  String _searchQuery = '';
  // Optional extra predicate (e.g. dropdown / date-range filters) that is
  // applied on top of the search. null = no extra filtering.
  bool Function(T item)? _extraFilter;
  final Set<String> _selectedIds = {};

  PaginatedDataController({
    required this.filterLogic,
    required this.sortLogic,
    required this.getItemId,
    int initialRowsPerPage = 25,
    int initialSortColumnIndex = 1,
  }) : _rowsPerPage = initialRowsPerPage,
       _sortColumnIndex = initialSortColumnIndex;

  // --- Getters for the UI ---
  List<T> get paginatedItems => _paginatedItems;

  /// Every item that passes search + extra filters (all pages, sorted).
  List<T> get filteredItems => _filteredItems;
  int get sortColumnIndex => _sortColumnIndex;
  bool get sortAscending => _sortAscending;
  int get rowsPerPage => _rowsPerPage;
  int get currentPage => _currentPage;
  Set<String> get selectedIds => _selectedIds;

  // --- Getters for Pagination Controls ---
  int get totalEntries => _filteredItems.length;
  int get totalPages => (totalEntries / _rowsPerPage).ceil();
  int get startEntry =>
      totalEntries == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1;
  int get endEntry => math.min(_currentPage * _rowsPerPage, totalEntries);

  // --- Public Methods (to be called by UI) ---

  /// Sets the master list of data and triggers the first sort/filter.
  void setData(List<T> allItems) {
    _allItems = allItems;
    _filteredItems = List.from(_allItems);
    _sortAndPaginate();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _currentPage = 1; // Reset to first page
    _sortAndPaginate();
  }

  /// Sets (or clears, with null) an extra filter applied on top of the search.
  /// Goes back to page 1 so the user never lands on a page that no longer
  /// exists after the result set shrinks.
  void setFilter(bool Function(T item)? predicate) {
    _extraFilter = predicate;
    _currentPage = 1;
    _sortAndPaginate();
  }

  void setSort(int columnIndex, bool ascending) {
    _sortColumnIndex = columnIndex;
    _sortAscending = ascending;
    _currentPage = 1; // Reset to first page
    _sortAndPaginate();
  }

  void setRowsPerPage(int? newRowsPerPage) {
    if (newRowsPerPage != null && newRowsPerPage != _rowsPerPage) {
      _rowsPerPage = newRowsPerPage;
      _currentPage = 1; // Reset to first page
      _sortAndPaginate();
    }
  }

  void goToPage(int page) {
    _currentPage = page;
    _sortAndPaginate();
  }

  void previousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      _sortAndPaginate();
    }
  }

  void nextPage() {
    if (_currentPage < totalPages) {
      _currentPage++;
      _sortAndPaginate();
    }
  }

  void onSelected(String id, bool? selected) {
    if (selected ?? false) {
      _selectedIds.add(id);
    } else {
      _selectedIds.remove(id);
    }
    notifyListeners();
  }

  /// Adds every id in [ids] to the selection (single notification).
  void selectAll(Iterable<String> ids) {
    _selectedIds.addAll(ids.where((id) => id.isNotEmpty));
    notifyListeners();
  }

  /// Removes every id in [ids] from the selection (single notification).
  void deselectAll(Iterable<String> ids) {
    _selectedIds.removeAll(ids);
    notifyListeners();
  }

  /// Clears the whole selection.
  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }

  /// Keeps only the selected ids that are still in [validIds]. Used after the
  /// data set changes (filters, deletes, live updates) so the selection can
  /// never point at rows that are no longer visible. Does not notify; call it
  /// right before [setData], which notifies.
  void retainSelection(Set<String> validIds) {
    _selectedIds.removeWhere((id) => !validIds.contains(id));
  }

  // --- Private Logic ---
  void _sortAndPaginate() {
    // 1. Apply Search + extra filters
    _filteredItems = _allItems.where((item) {
      return filterLogic(item, _searchQuery) &&
          (_extraFilter?.call(item) ?? true);
    }).toList();

    // 2. Apply Sorting
    _filteredItems.sort((a, b) {
      return sortLogic(a, b, _sortColumnIndex, _sortAscending);
    });

    // 3. Apply Pagination
    final int startIndex = (_currentPage - 1) * _rowsPerPage;
    final int endIndex = math.min(
      startIndex + _rowsPerPage,
      _filteredItems.length,
    );
    _paginatedItems = _filteredItems.sublist(startIndex, endIndex);

    // 4. Notify UI
    notifyListeners();
  }
}