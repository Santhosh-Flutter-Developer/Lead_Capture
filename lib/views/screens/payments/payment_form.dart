import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/views/screens/leads/form/lead_form_ui.dart';
import '/views/screens/project_updations/project_updation_form.dart'
    show masterClientLabel;

/// A deal shown in the Projects dropdown.
class _Proj {
  final String uid;
  final String label;
  final double dealValue;
  const _Proj(this.uid, this.label, this.dealValue);
}

/// A project updation of the selected project.
class _Upd {
  final String uid;
  final String label;
  final double value;
  const _Upd(this.uid, this.label, this.value);
}

/// One allocation waiting in the table below the form.
class _Line {
  String? uid; // set when it already exists in Firestore
  ClientModel client;
  _Proj project;
  MasterCompanyModel company;
  double allocated;
  String mode;
  String upi;
  _Upd? updation;
  List<FileModel> uploaded;
  List<PlatformFile> files;
  _Line({
    this.uid,
    required this.client,
    required this.project,
    required this.company,
    required this.allocated,
    required this.mode,
    this.upi = '',
    this.updation,
    this.uploaded = const [],
    this.files = const [],
  });
}

final NumberFormat _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// Payment form. Add several allocations (Master Client, Project, Master
/// Company, Allocate Value, Payment Mode) with the Add button, edit or
/// delete them in the table, then Submit to save them all.
///
/// Per project the allocated total can never exceed its deal value, and a
/// project that already has payments is not offered again. Pass [uid] to
/// edit an existing payment (its project stays available).
class PaymentForm extends StatefulWidget {
  final String? uid;
  const PaymentForm({super.key, this.uid});

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _vScroll = ScrollController();

  final _dealValue = TextEditingController();
  final _updValue = TextEditingController();
  final _clientRO = TextEditingController();
  final _projectRO = TextEditingController();
  final _allocate = TextEditingController();
  final _mode = TextEditingController();
  final _upi = TextEditingController();

  List<ClientModel> _clients = [];
  List<MasterCompanyModel> _companies = [];
  List<PaymentModel> _saved = [];
  List<_Proj> _projects = [];
  List<String> _modes = []; // names from the Payment Mode page

  ClientModel? _client;
  _Proj? _project;
  MasterCompanyModel? _company;
  _Upd? _updation;
  List<_Upd> _updations = [];
  List<ProjectUpdationModel> _allUpds = []; // every updation, any status
  final List<PlatformFile> _newFiles = [];
  List<FileModel> _uploaded = [];

  final List<_Line> _lines = [];
  final List<String> _removedUids = [];
  // Payments this form opened for editing (still in Firestore until submit).
  final Set<String> _origUids = {};
  int? _editingIndex;
  int _tick = 0; // forces dropdown rebuilds

  late Future<void> _future;

  bool get _isEdit => (widget.uid ?? '').isNotEmpty;

  bool get _isUpi => _mode.text.trim().toLowerCase() == 'upi';

  /// Once any allocation exists, Master Client, Project and Deal Value are
  /// fixed. They unlock again only after every allocation is deleted.
  bool get _locked => _lines.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _dealValue.dispose();
    _updValue.dispose();
    _clientRO.dispose();
    _projectRO.dispose();
    _allocate.dispose();
    _mode.dispose();
    _upi.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        ClientService.getMasterClients(),
        MasterCompanyService.getAll(),
        PaymentService.getAll(),
        PaymentModeService.getAllPaymentMode(),
        ProjectUpdationService.getAllUpdations(),
      ]);
      _allUpds = r[4] as List<ProjectUpdationModel>;
      _clients = r[0] as List<ClientModel>;
      _companies = r[1] as List<MasterCompanyModel>;
      _saved = r[2] as List<PaymentModel>;
      _modes = (r[3] as List<PaymentModeModel>)
          .map((m) => m.name.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (_isEdit) {
        final p = _saved.firstWhere(
          (e) => e.uid == widget.uid,
          orElse: () => throw 'Payment not found',
        );
        final client = _clients.where((c) => c.uid == p.clientId).firstOrNull;
        // Edit every allocation of this project together.
        for (final s in _saved.where((e) => e.projectId == p.projectId)) {
          final company =
              _companies.where((c) => c.uid == s.companyId).firstOrNull;
          if (client == null || company == null) continue;
          if (s.uid != null) _origUids.add(s.uid!);
          _lines.add(
            _Line(
              uid: s.uid,
              client: client,
              project: _Proj(s.projectId, s.projectName, s.dealValue),
              company: company,
              allocated: s.allocatedValue,
              mode: s.paymentMode,
              upi: s.upiNumber ?? '',
              uploaded: List<FileModel>.from(s.attachments),
              updation: (s.updationId ?? '').isEmpty
                  ? null
                  : _Upd(
                      s.updationId!,
                      s.updationLabel ?? 'Project Updation',
                      s.updationValue,
                    ),
            ),
          );
        }
      }
      _syncLocked();
      await _loadUpdations();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  /// While locked the entry always targets the first line's client/project.
  void _syncLocked() {
    if (_lines.isEmpty) return;
    _client = _lines.first.client;
    _project = _lines.first.project;
    _dealValue.text = _project!.dealValue.toStringAsFixed(2);
    _clientRO.text = masterClientLabel(_client!);
    _projectRO.text = _project!.label;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Deal value minus every other allocation of that project: lines in the
  /// table (except [excludeIndex]) and saved payments not being edited here.
  /// Amount still allocatable in one pool: the selected project updation's
  /// own value when [selected] is given, otherwise the deal value. Lines with
  /// a project updation never use up the deal value, and vice versa.
  double _remaining(_Proj p, {int? excludeIndex, _Upd? selected}) {
    final editingUids = _lines.map((l) => l.uid).whereType<String>().toSet();
    final updId = selected?.uid;
    double used = 0;
    for (final s in _saved) {
      if (s.projectId != p.uid ||
          editingUids.contains(s.uid) ||
          _removedUids.contains(s.uid)) {
        continue;
      }
      final sid = (s.updationId ?? '').isEmpty ? null : s.updationId;
      if (sid == updId) used += s.allocatedValue;
    }
    for (var i = 0; i < _lines.length; i++) {
      if (i == excludeIndex || _lines[i].project.uid != p.uid) continue;
      if (_lines[i].updation?.uid == updId) used += _lines[i].allocated;
    }
    return (selected?.value ?? p.dealValue) - used;
  }

  /// Updation dropdown items: updations that still have value
  /// left. Removing the allocation that used one up lists it again.
  List<_Upd> get _availableUpdations {
    final p = _project;
    if (p == null) return [];
    return _updations
        .where(
          (u) =>
              u.uid == _updation?.uid ||
              _remaining(p, excludeIndex: _editingIndex, selected: u) > 0.0001,
        )
        .toList();
  }

  /// Project updations (any status) of the selected project.
  Future<void> _loadUpdations() async {
    final id = _project?.uid;
    if (id == null || id.isEmpty) {
      _updations = [];
      return;
    }
    final list = await ProjectUpdationService.getAllUpdations(projectId: id);
    _updations = [
      for (final u in list)
        if (u.uid != null)
          _Upd(u.uid!, '${u.updationCode} - ${u.title}', u.value ?? 0),
    ];
    // Keep updations already used by lines selectable.
    for (final l in _lines) {
      final u = l.updation;
      if (l.project.uid == id && u != null && !_updations.any((x) => x.uid == u.uid)) {
        _updations.add(u);
      }
    }
  }

  Future<void> _loadProjects() async {
    final id = _client?.uid;
    if (id == null || id.isEmpty) {
      _projects = [];
      return;
    }
    final deals = (await DealService.getAllDeals())
        .where((d) => d.clientId == id)
        .toList()
      ..sort((a, b) => (a.projectName ?? a.dealName)
          .toLowerCase()
          .compareTo((b.projectName ?? b.dealName).toLowerCase()));
    // Deals (any status) are offered until the deal and all of its project
    // updations are fully allocated.
    // Payments opened for editing are never treated as "already paid", even
    // after their rows were removed here (they are deleted on submit).
    final editingUids = {
      ..._origUids,
      ..._lines.map((l) => l.uid).whereType<String>(),
    };
    final paid = <String>{};
    for (final d in deals) {
      final pid = d.uid;
      if (pid == null) continue;
      final others = _saved
          .where((s) => s.projectId == pid && !editingUids.contains(s.uid))
          .toList();
      double usedFor(String? updId) => others
          .where((s) => ((s.updationId ?? '').isEmpty ? null : s.updationId) == updId)
          .fold(0.0, (a, s) => a + s.allocatedValue);
      final dealOpen = d.dealValue - usedFor(null) > 0.0001;
      final updOpen = _allUpds.any(
        (u) =>
            u.projectId == pid &&
            u.uid != null &&
            (u.value ?? 0) - usedFor(u.uid) > 0.0001,
      );
      if (!dealOpen && !updOpen) paid.add(pid);
    }
    String nameOf(DealModel d) =>
        (d.projectName ?? '').trim().isEmpty ? d.dealName : d.projectName!;
    final counts = <String, int>{};
    for (final d in deals) {
      counts[nameOf(d)] = (counts[nameOf(d)] ?? 0) + 1;
    }
    _projects = [
      for (final d in deals)
        if (d.uid != null && !paid.contains(d.uid))
          _Proj(
            d.uid!,
            counts[nameOf(d)]! > 1 && d.dealNumber != null
                ? '${nameOf(d)} (#${d.dealNumber})'
                : nameOf(d),
            d.dealValue,
          ),
    ];
    // Keep a project that is being edited selectable.
    for (final l in _lines) {
      if (l.client.uid == id && !_projects.any((p) => p.uid == l.project.uid)) {
        _projects.add(l.project);
      }
    }
  }

  Future<void> _onClientChanged(ClientModel? c) async {
    _client = c;
    _project = null;
    _updations = [];
    _setUpdation(null);
    _dealValue.clear();
    try {
      await _loadProjects();
    } catch (e) {
      if (mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _onProjectChanged(_Proj? p) async {
    _project = p;
    _dealValue.text = p == null ? '' : p.dealValue.toStringAsFixed(2);
    _setUpdation(null);
    _updations = [];
    setState(() {});
    try {
      await _loadUpdations();
    } catch (e) {
      if (mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
    if (mounted) setState(() => _tick++);
  }

  void _setUpdation(_Upd? u) {
    _updation = u;
    _updValue.text = u == null ? '' : u.value.toStringAsFixed(2);
  }

  void _resetEntry({bool keepProject = false}) {
    _editingIndex = null;
    _company = null;
    _setUpdation(null);
    _allocate.clear();
    _mode.clear();
    _upi.clear();
    _newFiles.clear();
    _uploaded = [];
    if (!keepProject) {
      _project = null;
      _updations = [];
      _dealValue.clear();
    }
    _tick++;
  }

  Widget _plusButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Future<dynamic> _openSheet(Widget form) {
    if (kIsMobile) return Sheet.showSheet(context, widget: form);
    return GeneralDialog.showRTLSheet(context, form);
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void _addOrUpdate() {
    if (!_formKey.currentState!.validate()) return;
    final client = _client!;
    final project = _project!;
    final company = _company!;
    final amount = double.parse(_allocate.text.trim());
    final updation = _updation;
    final left = _remaining(
      project,
      excludeIndex: _editingIndex,
      selected: updation,
    );
    if (amount > left + 0.0001) {
      FlushBar.show(
        context,
        'Payment value exceeds the allowed value. Remaining: ${_money.format(left)}',
        isSuccess: false,
      );
      return;
    }
    setState(() {
      if (_editingIndex != null) {
        final l = _lines[_editingIndex!];
        l.client = client;
        l.project = project;
        l.company = company;
        l.allocated = amount;
        l.mode = _mode.text.trim();
        l.upi = _isUpi ? _upi.text.trim() : '';
        l.updation = updation;
        l.uploaded = List<FileModel>.from(_uploaded);
        l.files = List<PlatformFile>.from(_newFiles);
      } else {
        _lines.add(
          _Line(
            client: client,
            project: project,
            company: company,
            allocated: amount,
            mode: _mode.text.trim(),
            upi: _isUpi ? _upi.text.trim() : '',
            updation: updation,
            uploaded: List<FileModel>.from(_uploaded),
            files: List<PlatformFile>.from(_newFiles),
          ),
        );
      }
      _resetEntry(keepProject: true);
      _syncLocked();
    });
  }

  Future<void> _editLine(int i) async {
    final l = _lines[i];
    setState(() {
      _editingIndex = i;
      _syncLocked();
      _company = l.company;
      _setUpdation(l.updation);
      _allocate.text = l.allocated.toString();
      _mode.text = l.mode;
      _upi.text = l.upi;
      _uploaded = List<FileModel>.from(l.uploaded);
      _newFiles
        ..clear()
        ..addAll(l.files);
      _tick++;
    });
  }

  void _deleteLine(int i) {
    setState(() {
      final l = _lines.removeAt(i);
      if (l.uid != null) _removedUids.add(l.uid!);
      if (_editingIndex != null) _resetEntry(keepProject: _lines.isNotEmpty);
      if (_lines.isEmpty) {
        // Nothing allocated any more: client and project may change again.
        _client = null;
        _project = null;
        _projects = [];
        _updations = [];
        _setUpdation(null);
        _dealValue.clear();
        _tick++;
      } else {
        _syncLocked();
      }
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      FlushBar.show(
        context,
        'Add at least one payment allocation first',
        isSuccess: false,
      );
      return;
    }
    try {
      futureLoading(context);
      final user = await Spdb.getUser();
      final existing = {for (final s in _saved) s.uid: s};
      final attMap = <_Line, List<FileModel>>{};
      for (final l in _lines) {
        final atts = List<FileModel>.from(l.uploaded);
        if (l.files.isNotEmpty) {
          final data = await Future.wait(
            l.files.map((pf) async {
              final bytes = await platformFileToBytes(pf);
              return (bytes: bytes, fileName: pf.name);
            }),
          );
          final urls = await StorageService.uploadBytesInBatch(
            files: data,
            folder: StorageFolder.paymentAttachments,
          );
          for (var i = 0; i < l.files.length; i++) {
            final pf = l.files[i];
            atts.add(
              FileModel(
                name: pf.name,
                extension: pf.extension ?? '',
                size: pf.size,
                url: urls[i],
                mimeType: lookupMimeType(pf.name) ?? '',
              ),
            );
          }
        }
        attMap[l] = atts;
      }
      final models = [
        for (final l in _lines)
          PaymentModel(
            attachments: attMap[l] ?? const [],
            uid: l.uid,
            clientId: l.client.uid ?? '',
            clientLabel: masterClientLabel(l.client),
            projectId: l.project.uid,
            projectName: l.project.label,
            dealValue: l.project.dealValue,
            companyId: l.company.uid ?? '',
            companyName: l.company.companyName,
            allocatedValue: l.allocated,
            paymentMode: l.mode,
            upiNumber: l.upi.isEmpty ? null : l.upi,
            updationId: l.updation?.uid,
            updationLabel: l.updation?.label,
            updationValue: l.updation?.value ?? 0,
            createdBy: existing[l.uid]?.createdBy ?? user,
            createdAt: existing[l.uid]?.createdAt,
          ),
      ];
      await PaymentService.save(lines: models, removeUids: _removedUids);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, {"status": true});
      FlushBar.show(
        context,
        _isEdit ? 'Payment updated' : 'Payments added',
        isSuccess: true,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            }
            return Column(
              children: [
                LeadFormUI.header(
                  context,
                  title: _isEdit ? 'Edit Payment' : 'Add Payment',
                  subtitle: 'Allocate a deal across our companies',
                  icon: Iconsax.wallet_3,
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _vScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _vScroll,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Form(
                            key: _formKey,
                            child: LeadFormUI.sectionCard(
                              context,
                              title: 'Payment Details',
                              child: LayoutBuilder(
                                builder: (context, c) => _fields(c),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          LeadFormUI.sectionCard(
                            context,
                            title: 'Allocations (${_lines.length})',
                            child: _table(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: LeadFormUI.bottomBar(
          context,
          onSubmit: _submit,
          isEdit: _isEdit,
        ),
      ),
    );
  }

  Widget _fields(BoxConstraints constraints) {
    const double spacing = 16.0;
    const int gridCounts = 2;
    final canGrid =
        constraints.maxWidth >= (220.0 * gridCounts + spacing * (gridCounts - 1));
    final itemWidth = canGrid
        ? (constraints.maxWidth - spacing * (gridCounts - 1)) / gridCounts
        : constraints.maxWidth;
    Widget box(Widget child) => SizedBox(width: itemWidth, child: child);

    final remaining = _project == null
        ? null
        : _remaining(
            _project!,
            excludeIndex: _editingIndex,
            selected: _updation,
          );

    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      children: [
        // Master Client (+) - read-only once an allocation exists
        box(
          _locked
              ? FormFields(
                  key: ValueKey('client_ro_${_client?.uid}'),
                  label: 'Master Clients',
                  controller: _clientRO,
                  readOnly: true,
                )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FormDropdownSearch(
                  key: ValueKey('client_${_clients.length}_${_client?.uid}_$_tick'),
                  label: 'Master Clients',
                  isRequired: true,
                  initialItem: _client == null ? null : masterClientLabel(_client!),
                  items: _clients.map(masterClientLabel).toList(),
                  onChanged: (v) => _onClientChanged(
                    _clients.where((c) => masterClientLabel(c) == v).firstOrNull,
                  ),
                  validator: (v) => v == null ? '* Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              _plusButton(() async {
                final val = await _openSheet(const MasterClientForm());
                if (val is Map && val['status'] == true) {
                  _clients = await ClientService.getMasterClients();
                  if (val['client'] is ClientModel) {
                    await _onClientChanged(val['client'] as ClientModel);
                  } else if (mounted) {
                    setState(() {});
                  }
                }
              }),
            ],
          ),
        ),
        // Projects = the client's deals (any status) not fully allocated
        box(
          _locked
              ? FormFields(
                  key: ValueKey('proj_ro_${_project?.uid}'),
                  label: 'Projects',
                  controller: _projectRO,
                  readOnly: true,
                )
              : FormDropdownSearch(
            key: ValueKey('proj_${_client?.uid}_${_projects.length}_${_project?.uid}_$_tick'),
            label: 'Projects',
            isRequired: true,
            initialItem: _project?.label,
            items: _projects.map((p) => p.label).toList(),
            onChanged: (v) => _onProjectChanged(
              _projects.where((p) => p.label == v).firstOrNull,
            ),
            validator: (v) {
              if (_client == null) return '* Select a master client first';
              if (_projects.isEmpty) return '* No deals to allocate';
              return v == null ? '* Required' : null;
            },
          ),
        ),
        // Deal Value (auto-fetched)
        box(
          FormFields(
            label: 'Deal Value',
            controller: _dealValue,
            readOnly: true,
            hintText: 'Select a project',
          ),
        ),
        // Project Updations (optional): any status, not fully allocated
        box(
          FormDropdownSearch(
            key: ValueKey(
              'upd_${_project?.uid}_${_availableUpdations.length}_${_updation?.uid}_$_tick',
            ),
            label: 'Project Updations',
            allowClear: true,
            initialItem: _updation?.label,
            items: _availableUpdations.map((u) => u.label).toList(),
            onChanged: (v) => setState(
              () => _setUpdation(
                _availableUpdations.where((u) => u.label == v).firstOrNull,
              ),
            ),
            validator: (v) => null,
          ),
        ),
        // Project Updation Value (auto-fetched)
        box(
          FormFields(
            label: 'Project Updation Value',
            controller: _updValue,
            readOnly: true,
            hintText: 'Select a project updation',
          ),
        ),
        // Master Company (+)
        box(
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FormDropdownSearch(
                  key: ValueKey('comp_${_companies.length}_${_company?.uid}_$_tick'),
                  label: 'Our Company',
                  isRequired: true,
                  initialItem: _company?.companyName,
                  items: _companies.map((c) => c.companyName).toList(),
                  onChanged: (v) => _company = _companies
                      .where((c) => c.companyName == v)
                      .firstOrNull,
                  validator: (v) => v == null ? '* Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              _plusButton(() async {
                final val = await _openSheet(const MasterCompanyForm());
                if (val is Map && val['status'] == true) {
                  _companies = await MasterCompanyService.getAll();
                  if (val['company'] is MasterCompanyModel) {
                    _company = val['company'] as MasterCompanyModel;
                  }
                  if (mounted) setState(() => _tick++);
                }
              }),
            ],
          ),
        ),
        // Allocate Value
        box(
          FormFields(
            label: 'Payment Value',
            controller: _allocate,
            hintText: remaining == null
                ? 'Enter amount'
                : 'Remaining ${_money.format(remaining)}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            isRequired: true,
            valid: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return '* Payment value is required';
              final n = double.tryParse(t);
              if (n == null || n <= 0) return 'Enter a valid amount';
              if (_project != null) {
                final left = _remaining(
                  _project!,
                  excludeIndex: _editingIndex,
                  selected: _updation,
                );
                if (n > left + 0.0001) {
                  return "Can't exceed remaining ${_money.format(left)}";
                }
              }
              return null;
            },
          ),
        ),
        // Payment Mode
        box(
          FormDropdownSearch(
            key: ValueKey('mode_${_modes.length}_$_tick'),
            label: 'Payment Mode',
            isRequired: true,
            initialItem: _mode.text.isEmpty ? null : _mode.text,
            // A mode saved earlier that is no longer in the list stays
            // selectable so the payment can still be edited.
            items: [
              ..._modes,
              if (_mode.text.isNotEmpty && !_modes.contains(_mode.text))
                _mode.text,
            ],
            onChanged: (v) => setState(() {
              _mode.text = (v as String?) ?? '';
              if (!_isUpi) _upi.clear();
            }),
            validator: (v) => v == null ? '* Payment mode is required' : null,
          ),
        ),
        // UPI Number: only when the payment mode is UPI
        if (_isUpi)
          box(
            FormFields(
              label: 'UPI Number',
              controller: _upi,
              hintText: 'Enter UPI number / ID',
              isRequired: true,
              valid: (v) => (v == null || v.trim().isEmpty)
                  ? '* UPI number is required'
                  : null,
            ),
          ),
        // Attachments (optional)
        SizedBox(
          width: constraints.maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormFields(
                label: 'Attachments',
                hintText: 'Tap to select files',
                suffixIcon: const Icon(Iconsax.document_upload),
                readOnly: true,
                onTap: () async {
                  final files = await FilePick.pickFiles(context);
                  if (files != null && files.isNotEmpty) {
                    _newFiles.addAll(files);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                children: [
                  ..._uploaded.map(
                    (f) => AttachmentPill(
                      name: f.name,
                      onRemove: () => setState(() => _uploaded.remove(f)),
                    ),
                  ),
                  ..._newFiles.map(
                    (f) => AttachmentPill(
                      name: f.name,
                      onRemove: () => setState(() => _newFiles.remove(f)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: constraints.maxWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              children: [
                if (_editingIndex != null)
                  OutlinedButton(
                    onPressed: () => setState(() => _resetEntry(keepProject: _locked)),
                    child: const Text('Cancel'),
                  ),
                FilledButton.icon(
                  onPressed: _addOrUpdate,
                  icon: Icon(
                    _editingIndex == null ? Icons.add_rounded : Icons.check_rounded,
                    size: 18,
                  ),
                  label: Text(_editingIndex == null ? 'Add' : 'Update'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    if (_lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'No allocations added yet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    final style = Theme.of(context).textTheme.bodySmall;
    // One line per project: everything allocated (deal + project updations)
    // against the deal value plus the value of the updations used.
    final used = <String, double>{};
    final limit = <String, double>{};
    final updSeen = <String, Set<String>>{};
    for (final l in _lines) {
      final key = l.project.label;
      used[key] = (used[key] ?? 0) + l.allocated;
      limit[key] ??= l.project.dealValue;
      if (l.updation != null && (updSeen[key] ??= {}).add(l.updation!.uid)) {
        limit[key] = limit[key]! + l.updation!.value;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Master Client')),
              DataColumn(label: Text('Project')),
              DataColumn(label: Text('Project Updation')),
              DataColumn(label: Text('Our Company')),
              DataColumn(label: Text('Payment Value'), numeric: true),
              DataColumn(label: Text('Payment Mode')),
              DataColumn(label: Text('UPI Number')),
              DataColumn(label: Text('Attachments')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (var i = 0; i < _lines.length; i++)
                DataRow(
                  selected: _editingIndex == i,
                  cells: [
                    DataCell(Text(masterClientLabel(_lines[i].client), style: style)),
                    DataCell(Text(_lines[i].project.label, style: style)),
                    DataCell(Text(_lines[i].updation?.label ?? '-', style: style)),
                    DataCell(Text(_lines[i].company.companyName, style: style)),
                    DataCell(Text(_money.format(_lines[i].allocated), style: style)),
                    DataCell(Text(_lines[i].mode, style: style)),
                    DataCell(Text(_lines[i].upi.isEmpty ? '-' : _lines[i].upi, style: style)),
                    DataCell(Text(
                      (_lines[i].uploaded.length + _lines[i].files.length) == 0
                          ? '-'
                          : '${_lines[i].uploaded.length + _lines[i].files.length} file(s)',
                      style: style,
                    )),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Iconsax.edit, size: 18),
                            onPressed: () => _editLine(i),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Iconsax.trash, size: 18),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => _deleteLine(i),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final key in used.keys)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$key: allocated ${_money.format(used[key])} of '
              '${_money.format(limit[key])}',
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}