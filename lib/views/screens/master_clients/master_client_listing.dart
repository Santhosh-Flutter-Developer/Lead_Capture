import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';

const double _wideBreakpoint = 900;

typedef _Stats = ({int leads, int deals, double value});

/// Master Client list: company + contact captured once, reused by every
/// Lead, Deal and Project. Shows leads count, deals count and total deal
/// value per client.
class MasterClientListing extends StatefulWidget {
  const MasterClientListing({super.key});

  @override
  State<MasterClientListing> createState() => _MasterClientListingState();
}

class _MasterClientListingState extends State<MasterClientListing> {
  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  late final PaginatedDataController<ClientModel> _controller;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  Map<String, _Stats> _stats = {};
  List<ClientModel> _all = [];
  PermissionModel? _permissions;
  bool _loading = true;
  String? _error;

  // Search + location filters (Country -> State -> District -> City).
  String _searchText = '';
  String? _fCountry;
  String? _fState;
  String? _fDistrict;
  String? _fCity;
  // Bumped by "Clear filters" so the dropdowns rebuild with no selection.
  int _filterEpoch = 0;
  List<String> _countryOpts = [];
  List<String> _stateOpts = [];
  List<String> _districtOpts = [];
  List<String> _cityOpts = [];

  bool get _hasLocationFilter =>
      _fCountry != null ||
      _fState != null ||
      _fDistrict != null ||
      _fCity != null;

  static String _n(String? v) => (v ?? '').trim().toLowerCase();

  bool _same(String? value, String? selected) =>
      selected == null || _n(value) == _n(selected);

  _Stats _statsOf(ClientModel c) =>
      _stats[c.uid] ?? (leads: 0, deals: 0, value: 0.0);

  @override
  void initState() {
    super.initState();
    _controller = PaginatedDataController<ClientModel>(
      initialSortColumnIndex: 0,
      filterLogic: (c, query) {
        if (!_same(c.country?.name, _fCountry) ||
            !_same(c.state?.name, _fState) ||
            !_same(c.district?.name, _fDistrict) ||
            !_same(c.city?.name, _fCity)) {
          return false;
        }
        final q = query.toLowerCase();
        if (q.isEmpty) return true;
        return (c.companyName ?? '').toLowerCase().contains(q) ||
            (c.clientName ?? '').toLowerCase().contains(q) ||
            (c.mobileNumber ?? '').toLowerCase().contains(q) ||
            (c.gstVatNumber ?? '').toLowerCase().contains(q) ||
            (c.companyAddress ?? '').toLowerCase().contains(q) ||
            (c.postalCode ?? '').toLowerCase().contains(q) ||
            (c.country?.name ?? '').toLowerCase().contains(q) ||
            (c.state?.name ?? '').toLowerCase().contains(q) ||
            (c.district?.name ?? '').toLowerCase().contains(q) ||
            (c.city?.name ?? '').toLowerCase().contains(q);
      },
      sortLogic: (a, b, col, asc) {
        int compare;
        switch (col) {
          case 0:
            compare = (a.companyName ?? '').toLowerCase().compareTo(
              (b.companyName ?? '').toLowerCase(),
            );
            break;
          case 1:
            compare = (a.clientName ?? '').toLowerCase().compareTo(
              (b.clientName ?? '').toLowerCase(),
            );
            break;
          case 3:
            compare = _cmp(a.companyAddress, b.companyAddress);
            break;
          case 4:
            compare = _cmp(a.country?.name, b.country?.name);
            break;
          case 5:
            compare = _cmp(a.state?.name, b.state?.name);
            break;
          case 6:
            compare = _cmp(a.district?.name, b.district?.name);
            break;
          case 7:
            compare = _cmp(a.city?.name, b.city?.name);
            break;
          case 8:
            compare = _cmp(a.postalCode, b.postalCode);
            break;
          case 9:
            compare = _statsOf(a).leads.compareTo(_statsOf(b).leads);
            break;
          case 10:
            compare = _statsOf(a).deals.compareTo(_statsOf(b).deals);
            break;
          case 11:
            compare = _statsOf(a).value.compareTo(_statsOf(b).value);
            break;
          default:
            compare = (a.uid ?? '').compareTo(b.uid ?? '');
        }
        return asc ? compare : -compare;
      },
      getItemId: (c) => c.uid ?? '',
    );
    _load();
  }

  int _cmp(String? a, String? b) => _n(a).compareTo(_n(b));

  /// Loads the full Country list (same offline data the add form uses).
  Future<void> _loadCountryOptions() async {
    final countries = await RegionDataService.getCountries();
    _countryOpts = countries.map((e) => e.name).toList();
  }

  Future<void> _loadStateOptions() async {
    final states = await RegionDataService.getStates(country: _fCountry);
    _stateOpts = states.map((e) => e.name).toList();
  }

  Future<void> _loadDistrictOptions() async {
    final districts = await RegionDataService.getDistricts(
      country: _fCountry,
      state: _fState,
    );
    _districtOpts = districts.map((e) => e.name).toList();
  }

  Future<void> _loadCityOptions() async {
    final cities = await RegionDataService.getCities(
      country: _fCountry,
      state: _fState,
      district: _fDistrict,
    );
    _cityOpts = cities.map((e) => e.name).toList();
  }

  /// Re-applies search + location filters (goes back to page 1).
  void _applyFilters() {
    _controller.clearSelection();
    _controller.setSearch(_searchText);
  }

  Future<void> _onCountryFilter(String? v) async {
    _fCountry = v;
    _fState = _fDistrict = _fCity = null;
    _stateOpts = [];
    _districtOpts = [];
    _cityOpts = [];
    await _loadStateOptions();
    if (!mounted) return;
    setState(_applyFilters);
  }

  Future<void> _onStateFilter(String? v) async {
    _fState = v;
    _fDistrict = _fCity = null;
    _districtOpts = [];
    _cityOpts = [];
    await _loadDistrictOptions();
    if (!mounted) return;
    setState(_applyFilters);
  }

  Future<void> _onDistrictFilter(String? v) async {
    _fDistrict = v;
    _fCity = null;
    _cityOpts = [];
    await _loadCityOptions();
    if (!mounted) return;
    setState(_applyFilters);
  }

  void _onCityFilter(String? v) {
    _fCity = v;
    setState(_applyFilters);
  }

  void _clearFilters() {
    _fCountry = _fState = _fDistrict = _fCity = null;
    _stateOpts = [];
    _districtOpts = [];
    _cityOpts = [];
    _filterEpoch++;
    _applyFilters();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  /// Refresh button: show the loader, then reload clients, stats and
  /// permissions (the search text stays as typed).
  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _load() async {
    try {
      // Roles created before "Master Client" existed only have the old
      // Company / Contact pages, so fall back to those.
      _permissions =
          await PermissionService.getPermissions('Master Client') ??
          await PermissionService.getPermissions('Company');
      final clients = await ClientService.getMasterClients();
      final stats = await ClientService.getClientStats();
      if (!mounted) return;
      _all = clients;
      _stats = stats;
      if (_countryOpts.isEmpty) await _loadCountryOptions();
      _controller.setData(clients);
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  Future<void> _openForm(BuildContext context, {String? uid}) async {
    final form = MasterClientForm(uid: uid);
    dynamic val;
    if (_isWide(context)) {
      val = await GeneralDialog.showRTLSheet(context, form);
    } else {
      val = await Sheet.showSheet(context, widget: form);
    }
    if (val is Map && val['status'] == true) await _load();
  }

  /// Bulk import (xlsx / csv). Refreshes the list when something was imported.
  Future<void> _openUpload(BuildContext context) async {
    const upload = MasterClientUpload();
    dynamic val;
    if (_isWide(context)) {
      val = await GeneralDialog.showRTLSheet(context, upload);
    } else {
      val = await Sheet.showSheet(context, widget: upload);
    }
    if (val == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWide(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: const Text('Master Client'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
      body: Builder(
        builder: (context) {
          if (_loading) return const WaitingLoading();
          if (_error != null) {
            return Center(
              child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            );
          }
          if (!(_permissions?.canView ?? false)) {
            return buildNoPermissionView(context);
          }
          return ChangeNotifierProvider<PaginatedDataController<ClientModel>>.value(
            value: _controller,
            child: Consumer<PaginatedDataController<ClientModel>>(
              builder: (context, controller, _) => RefreshIndicator(
                onRefresh: _load,
                child: Scrollbar(
                  controller: _vScroll,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _vScroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                    children: [
                      if (isWide) ...[
                        _banner(context),
                        const SizedBox(height: 20),
                      ],
                      _toolbar(context, controller, isWide),
                      const SizedBox(height: 12),
                      _filterBar(context, isWide),
                      const SizedBox(height: 18),
                      controller.paginatedItems.isEmpty
                          ? NoData(
                              text: _all.isEmpty
                                  ? 'No master clients available'
                                  : 'No matching records found',
                            )
                          : _tableCard(context, controller),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Iconsax.people, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Master Client',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capture a customer once, then raise any number of leads and deals',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '${_all.length}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Clients',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(
    BuildContext context,
    PaginatedDataController<ClientModel> controller,
    bool isWide,
  ) {
    final selected = controller.selectedIds.length;
    final buttons = <Widget>[
      if (_permissions?.canCreate ?? false)
        FilledButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Master Client'),
        ),
      if (_permissions?.canImport ?? false) ...[
        FilledButton.tonalIcon(
          onPressed: () => _openUpload(context),
          icon: const Icon(Iconsax.cloud_plus, size: 18),
          label: const Text('Upload'),
        ),
        // Sample template / sample data download
        PopupMenuButton<String>(
          tooltip: 'Download template',
          onSelected: (v) => Download.downloadFromAsset(
            context,
            v == 'template'
                ? 'assets/templates/master_client_upload_template.xlsx'
                : 'assets/templates/master_client_upload_template_with_data.xlsx',
            v == 'template'
                ? 'Master Client Template.xlsx'
                : 'Master Client Sample Data.xlsx',
          ),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'template',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.file_download_outlined),
                title: Text('Master Client Template'),
              ),
            ),
            PopupMenuItem(
              value: 'sample',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.contact_page_outlined),
                title: Text('Sample Master Client Data'),
              ),
            ),
          ],
          child: IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Iconsax.document_download, size: 18),
              label: const Text('Template'),
            ),
          ),
        ),
      ],
      if ((_permissions?.canExport ?? false) &&
          controller.paginatedItems.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _export(context, controller),
          icon: const Icon(Iconsax.export_3, size: 18),
          label: const Text('Export'),
        ),
      if (selected > 0 && (_permissions?.canDelete ?? false))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => _bulkDelete(context, controller),
          icon: const Icon(Iconsax.trash, size: 18),
          label: Text('Delete ($selected)'),
        ),
      IconButton(
        tooltip: 'Refresh',
        onPressed: _refresh,
        icon: const Icon(Iconsax.refresh),
      ),
    ];

    final search = SizedBox(
      width: isWide ? 300 : double.infinity,
      child: TextField(
        onChanged: (v) {
          _searchText = v;
          controller.setSearch(v);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search company, contact, mobile, GST, address',
          prefixIcon: const Icon(Iconsax.search_normal_1, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: isWide
          ? Row(
              children: [
                search,
                const Spacer(),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            ),
    );
  }

  Widget _filterBar(BuildContext context, bool isWide) {
    Widget slot(Widget child) => isWide
        ? Expanded(child: child)
        : Padding(padding: const EdgeInsets.only(bottom: 12), child: child);

    final fields = <Widget>[
      slot(
        FormDropdownSearch(
          key: ValueKey('f_country_${_filterEpoch}_${_countryOpts.length}'),
          label: 'Country',
          initialItem: _fCountry,
          items: _countryOpts,
          onChanged: (v) => _onCountryFilter(v as String?),
        ),
      ),
      slot(
        FormDropdownSearch(
          key: ValueKey(
            'f_state_${_filterEpoch}_${_fCountry}_${_stateOpts.length}',
          ),
          label: 'State',
          initialItem: _fState,
          items: _stateOpts,
          onChanged: (v) => _onStateFilter(v as String?),
        ),
      ),
      slot(
        FormDropdownSearch(
          key: ValueKey(
            'f_district_${_filterEpoch}_${_fState}_${_districtOpts.length}',
          ),
          label: 'District',
          initialItem: _fDistrict,
          items: _districtOpts,
          onChanged: (v) => _onDistrictFilter(v as String?),
        ),
      ),
      slot(
        FormDropdownSearch(
          key: ValueKey(
            'f_city_${_filterEpoch}_${_fDistrict}_${_cityOpts.length}',
          ),
          label: 'City',
          initialItem: _fCity,
          items: _cityOpts,
          onChanged: (v) => _onCityFilter(v as String?),
        ),
      ),
    ];

    final clear = TextButton.icon(
      onPressed: _hasLocationFilter ? () => setState(_clearFilters) : null,
      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
      label: const Text('Clear filters'),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final f in fields) ...[f, const SizedBox(width: 12)],
                clear,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...fields, Align(alignment: Alignment.centerRight, child: clear)],
            ),
    );
  }

  Widget _tableCard(
    BuildContext context,
    PaginatedDataController<ClientModel> controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: LayoutBuilder(
              builder: (context, constraints) => Scrollbar(
                controller: _hScroll,
                thumbVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: true,
                      sortColumnIndex: controller.sortColumnIndex,
                      sortAscending: controller.sortAscending,
                      headingRowColor: WidgetStateProperty.all(
                        scheme.primary.withValues(alpha: 0.06),
                      ),
                      headingTextStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                      columns: [
                        DataColumn(
                          label: const Text('Company'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Contact'),
                          onSort: controller.setSort,
                        ),
                        const DataColumn(label: Text('Mobile')),
                        DataColumn(
                          label: const Text('Address'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Country'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('State'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('District'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('City'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Postal Code'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Leads'),
                          numeric: true,
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Deals'),
                          numeric: true,
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Total Deal Value'),
                          numeric: true,
                          onSort: controller.setSort,
                        ),
                        const DataColumn(label: Text('Created By')),
                        const DataColumn(label: Text('Action')),
                      ],
                      rows: controller.paginatedItems
                          .map((c) => _row(context, c, controller))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<ClientModel>(),
          ),
        ],
      ),
    );
  }

  String _dash(String? v) => (v ?? '').trim().isEmpty ? '-' : v!.trim();

  DataRow _row(
    BuildContext context,
    ClientModel c,
    PaginatedDataController<ClientModel> controller,
  ) {
    final style = Theme.of(context).textTheme.bodySmall;
    final s = _statsOf(c);
    return DataRow(
      selected: controller.selectedIds.contains(c.uid),
      onSelectChanged: (v) => controller.onSelected(c.uid!, v),
      cells: [
        DataCell(
          Text(
            c.companyName ?? '-',
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
          onTap: (_permissions?.canEdit ?? false)
              ? () => _openForm(context, uid: c.uid)
              : null,
        ),
        DataCell(Text(c.clientName?.isNotEmpty == true ? c.clientName! : '-', style: style)),
        DataCell(Text(c.mobileNumber?.isNotEmpty == true ? c.mobileNumber! : '-', style: style)),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Tooltip(
              message: c.companyAddress ?? '',
              child: Text(
                _dash(c.companyAddress),
                style: style,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        DataCell(Text(_dash(c.country?.name), style: style)),
        DataCell(Text(_dash(c.state?.name), style: style)),
        DataCell(Text(_dash(c.district?.name), style: style)),
        DataCell(Text(_dash(c.city?.name), style: style)),
        DataCell(Text(_dash(c.postalCode), style: style)),
        DataCell(Text('${s.leads}', style: style)),
        DataCell(Text('${s.deals}', style: style)),
        DataCell(Text(s.value.toStringAsFixed(2), style: style)),
        DataCell(CreatedByWidget(userData: c.createdBy)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_permissions?.canEdit ?? false)
                IconButton(
                  tooltip: 'Edit',
                  color: AppColors.info,
                  icon: const Icon(Iconsax.edit),
                  onPressed: () => _openForm(context, uid: c.uid),
                ),
              if (_permissions?.canDelete ?? false)
                IconButton(
                  tooltip: 'Delete',
                  color: AppColors.danger,
                  icon: const Icon(Iconsax.trash),
                  onPressed: () => _delete(context, c),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    PaginatedDataController<ClientModel> controller,
  ) async {
    try {
      final rows = <List<String>>[
        [
          'Company',
          'Contact Name',
          'Contact Mobile',
          'Office Phone',
          'GST/VAT',
          'Country',
          'State',
          'District',
          'City',
          'Postal Code',
          'Address',
          'Leads',
          'Deals',
          'Total Deal Value',
          'Created By',
        ],
        for (final c in controller.paginatedItems)
          [
            c.companyName ?? '',
            c.clientName ?? '',
            c.mobileNumber ?? '',
            c.officePhoneNo ?? '',
            c.gstVatNumber ?? '',
            c.country?.name ?? '',
            c.state?.name ?? '',
            c.district?.name ?? '',
            c.city?.name ?? '',
            c.postalCode ?? '',
            c.companyAddress ?? '',
            '${_statsOf(c).leads}',
            '${_statsOf(c).deals}',
            _statsOf(c).value.toStringAsFixed(2),
            c.createdBy.name,
          ],
      ];
      final bytes = await XlsxWriter().create(rows);
      final path = await saveFileToDownloads(
        bytes,
        fileName: 'Master Client List.xlsx',
      );
      if (!kIsWeb && context.mounted) openfile(path, context);
    } catch (e) {
      if (!context.mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<bool> _confirmDelete(BuildContext context, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Master Client',
        content: count == 1
            ? 'Are you sure you want to delete this master client?'
            : 'Are you sure you want to delete $count master clients?',
      ),
    );
    return ok == true;
  }

  Future<void> _blocked(BuildContext context) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cannot Delete'),
      content: const Text(
        'This client is linked to leads or deals. Remove those first.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );

  Future<void> _delete(BuildContext context, ClientModel c) async {
    if (await ClientService.isClientAssigned(c.uid ?? '')) {
      if (context.mounted) await _blocked(context);
      return;
    }
    if (!context.mounted || !await _confirmDelete(context, 1)) return;
    try {
      final deleted = c.copyWith();
      futureLoading(context);
      try {
        await ClientService.deleteClient(uid: c.uid ?? '');
      } finally {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      await _load();
      if (!context.mounted) return;
      FlushBar.show(
        context,
        'Master client deleted',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          await ClientService.restoreClient(deleted);
          await _load();
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (context.mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
  }

  Future<void> _bulkDelete(
    BuildContext context,
    PaginatedDataController<ClientModel> controller,
  ) async {
    final chosen = _all
        .where((c) => controller.selectedIds.contains(c.uid))
        .toList();
    if (chosen.isEmpty) return;
    for (final c in chosen) {
      if (await ClientService.isClientAssigned(c.uid ?? '')) {
        if (context.mounted) await _blocked(context);
        return;
      }
    }
    if (!context.mounted || !await _confirmDelete(context, chosen.length)) {
      return;
    }
    try {
      final deleted = chosen.map((e) => e.copyWith()).toList();
      futureLoading(context);
      try {
        for (final c in chosen) {
          await ClientService.deleteClient(uid: c.uid ?? '');
        }
      } finally {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      controller.clearSelection();
      await _load();
      if (!context.mounted) return;
      FlushBar.show(
        context,
        'Master clients deleted',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (final c in deleted) {
            await ClientService.restoreClient(c);
          }
          await _load();
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (context.mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
  }
}