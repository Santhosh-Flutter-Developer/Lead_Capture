import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import '/models/models.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/views/screens/leads/form/lead_form_ui.dart';

String masterClientLabel(ClientModel c) {
  final contact = (c.clientName ?? '').trim();
  return contact.isEmpty ? c.displayName : '${c.displayName} - $contact';
}

/// A completed deal shown in the Project dropdown.
class _ProjectOption {
  final String uid;
  final String label;
  const _ProjectOption(this.uid, this.label);
}

/// Create / edit form for a Project Updation (a change request raised on a
/// completed deal / project). Pass [uid] to edit. Pops `true` after saving.
///
/// Field order: Master Client, Company, Contact Name, Contact Mobile, Project,
/// Updation Title, Updation Description, Requested Date, Status, Updation
/// Value, Note, Attachments.
class ProjectUpdationForm extends StatefulWidget {
  final String? uid;
  const ProjectUpdationForm({super.key, this.uid});

  @override
  State<ProjectUpdationForm> createState() => _ProjectUpdationFormState();
}

class _ProjectUpdationFormState extends State<ProjectUpdationForm> {
  final _formKey = GlobalKey<FormState>();
  final _vScroll = ScrollController();

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _requestedDate = TextEditingController();
  final _value = TextEditingController();
  final _notes = TextEditingController();
  final _company = TextEditingController();
  final _contact = TextEditingController();
  final _mobile = TextEditingController();

  final _dateFmt = DateFormat('dd MMM yyyy');

  late Future<void> _future;
  ProjectUpdationModel? _existing;

  List<ClientModel> _clients = [];
  List<_ProjectOption> _projects = [];

  ClientModel? _client;
  _ProjectOption? _project;
  DateTime _requested = DateTime.now();
  UpdationStatus _status = UpdationStatus.pending;

  // Follow Up (optional): only this employee and admins can see the updation.
  List<EmployeeModel> _employees = [];
  Map<String, String> _employeeLabels = {}; // uid -> label
  String? _followUp; // employee uid

  final List<PlatformFile> _newFiles = [];
  List<FileModel> _uploaded = [];

  bool get _isEdit => (widget.uid ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _requestedDate.text = _dateFmt.format(_requested);
    _future = _init();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    for (final c in [
      _title,
      _description,
      _requestedDate,
      _value,
      _notes,
      _company,
      _contact,
      _mobile,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _clients = await ClientService.getMasterClients();
      try {
        _employees = await FollowUpAccess.employees();
        _employeeLabels = FollowUpAccess.labelsByUid(_employees);
      } catch (_) {
        // Follow Up is optional: never block the form if it can't load.
      }

      if (_isEdit) {
        final u = await ProjectUpdationService.getUpdation(uid: widget.uid!);
        _existing = u;
        _followUp = u.followUp;
        _title.text = u.title;
        _description.text = u.description;
        _requested = u.requestedDate;
        _requestedDate.text = _dateFmt.format(u.requestedDate);
        _value.text = u.value == null ? '' : u.value.toString();
        _notes.text = u.notes;
        _status = u.status;
        _uploaded = List<FileModel>.from(u.attachments);
        _client = _clients.cast<ClientModel?>().firstWhere(
          (c) => c?.uid == u.clientId,
          orElse: () => null,
        );
        if (_client != null) {
          _syncClientFields();
          await _loadProjects();
        } else {
          _company.text = u.companyName ?? '';
          _contact.text = u.contactName ?? '';
          _mobile.text = u.contactMobile ?? '';
        }
        // Keep the saved project selectable even if its deal is no longer
        // in a completed stage.
        _project = _projects.cast<_ProjectOption?>().firstWhere(
          (p) => p?.uid == u.projectId,
          orElse: () => null,
        );
        if (_project == null && u.projectId.isNotEmpty) {
          _project = _ProjectOption(u.projectId, u.projectName);
          _projects = [..._projects, _project!];
        }
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  void _syncClientFields() {
    _company.text = _client?.companyName ?? '';
    _contact.text = _client?.clientName ?? '';
    _mobile.text = _client?.mobileNumber ?? '';
  }

  /// Projects = the selected master client's completed deals.
  Future<void> _loadProjects() async {
    final id = _client?.uid;
    if (id == null || id.isEmpty) {
      _projects = [];
      return;
    }
    final deals = await DealService.getCompletedDealsByClient(clientId: id);
    String nameOf(DealModel d) =>
        (d.projectName ?? '').trim().isEmpty ? d.dealName : d.projectName!;
    final counts = <String, int>{};
    for (final d in deals) {
      counts[nameOf(d)] = (counts[nameOf(d)] ?? 0) + 1;
    }
    _projects = [
      for (final d in deals)
        _ProjectOption(
          d.uid ?? '',
          counts[nameOf(d)]! > 1 && d.dealNumber != null
              ? '${nameOf(d)} (#${d.dealNumber})'
              : nameOf(d),
        ),
    ];
  }

  Future<void> _onClientChanged(String? v) async {
    _client = _clients.cast<ClientModel?>().firstWhere(
      (c) => c != null && masterClientLabel(c) == v,
      orElse: () => null,
    );
    _project = null;
    _syncClientFields();
    try {
      await _loadProjects();
    } catch (e) {
      if (mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requested,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _requested = picked;
      _requestedDate.text = _dateFmt.format(picked);
    });
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
                  title: _isEdit
                      ? 'Edit Project Updation'
                      : 'Create Project Updation',
                  subtitle: 'Track a change requested on a completed project',
                  icon: Iconsax.refresh_circle,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Scrollbar(
                      controller: _vScroll,
                      thumbVisibility: true,
                      interactive: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                        controller: _vScroll,
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          child: LeadFormUI.sectionCard(
                            context,
                            title: 'Updation Details',
                            child: LayoutBuilder(
                              builder: (context, c) => _fields(c, 3),
                            ),
                          ),
                        ),
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

  Widget _fields(BoxConstraints constraints, int gridCounts) {
    const spacing = 16.0;
    const minWidth = 220.0;
    final canGrid =
        constraints.maxWidth >=
        (minWidth * gridCounts + spacing * (gridCounts - 1));
    final w = canGrid
        ? (constraints.maxWidth - spacing * (gridCounts - 1)) / gridCounts
        : constraints.maxWidth;

    Widget box(Widget child) => SizedBox(width: w, child: child);
    Widget full(Widget child) =>
        SizedBox(width: constraints.maxWidth, child: child);
    String? req(String? v, String l) =>
        (v == null || v.trim().isEmpty) ? '* $l is required' : null;

    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      children: [
        // 1. Master Client (+)
        box(
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FormDropdownSearch(
                  key: ValueKey('client_${_clients.length}_${_client?.uid}'),
                  label: 'Master Client',
                  isRequired: true,
                  initialItem: _client == null
                      ? null
                      : masterClientLabel(_client!),
                  items: _clients.map(masterClientLabel).toList(),
                  onChanged: (v) => _onClientChanged(v as String?),
                  validator: (v) => v == null ? '* Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              _plusButton(() async {
                const form = MasterClientForm();
                dynamic val;
                if (kIsMobile) {
                  val = await Sheet.showSheet(context, widget: form);
                } else {
                  val = await GeneralDialog.showRTLSheet(context, form);
                }
                if (val is Map && val['status'] == true) {
                  _clients = await ClientService.getMasterClients();
                  if (val['client'] is ClientModel) {
                    _client = val['client'] as ClientModel;
                    _project = null;
                    _syncClientFields();
                    await _loadProjects();
                  }
                  if (mounted) setState(() {});
                }
              }),
            ],
          ),
        ),
        // 2-4. Read-only, fetched from the master client
        box(FormFields(label: 'Company', controller: _company, readOnly: true)),
        box(
          FormFields(
            label: 'Contact Name',
            controller: _contact,
            readOnly: true,
          ),
        ),
        box(
          FormFields(
            label: 'Contact Mobile',
            controller: _mobile,
            readOnly: true,
          ),
        ),
        // 5. Project = this client's completed deals
        box(
          FormDropdownSearch(
            key: ValueKey(
              'project_${_client?.uid}_${_projects.length}_${_project?.uid}',
            ),
            label: 'Project',
            isRequired: true,
            initialItem: _project?.label,
            items: _projects.map((p) => p.label).toList(),
            onChanged: (v) {
              _project = _projects.cast<_ProjectOption?>().firstWhere(
                (p) => p?.label == v,
                orElse: () => null,
              );
            },
            validator: (v) {
              if (_client == null) return '* Select a master client first';
              if (_projects.isEmpty) return '* No completed deals for client';
              return v == null ? '* Required' : null;
            },
          ),
        ),
        // 6. Title
        box(
          FormFields(
            label: 'Updation Title',
            controller: _title,
            hintText: 'e.g. Add invoice export',
            isRequired: true,
            valid: (v) => req(v, 'Title'),
          ),
        ),
        // 7. Description
        full(
          FormFields(
            label: 'Updation Description',
            controller: _description,
            hintText: 'Describe the change requested',
            maxLines: 3,
            isRequired: true,
            valid: (v) => req(v, 'Description'),
          ),
        ),
        // 8. Requested date
        box(
          FormFields(
            label: 'Requested Date',
            controller: _requestedDate,
            readOnly: true,
            isRequired: true,
            suffixIcon: const Icon(Iconsax.calendar_1),
            onTap: _pickDate,
            valid: (v) => req(v, 'Requested date'),
          ),
        ),
        // 9. Status
        box(
          FormDropdownSearch(
            key: ValueKey('status_${_status.name}'),
            label: 'Status',
            isRequired: true,
            allowClear: false,
            initialItem: _status.label,
            items: UpdationStatus.values.map((s) => s.label).toList(),
            onChanged: (v) {
              _status = UpdationStatus.values.firstWhere(
                (s) => s.label == v,
                orElse: () => UpdationStatus.pending,
              );
            },
            validator: (v) => v == null ? '* Required' : null,
          ),
        ),
        // 10. Value
        box(
          FormFields(
            label: 'Updation Value',
            controller: _value,
            hintText: 'Enter amount',
            keyboardType: TextInputType.number,
            valid: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return double.tryParse(v.trim()) == null
                  ? 'Enter a number'
                  : null;
            },
          ),
        ),
        // Follow Up (optional)
        box(
          FormDropdownSearch(
            key: ValueKey('followup_${_employees.length}'),
            label: 'Follow Up',
            initialItem: _employeeLabels[_followUp],
            items: _employeeLabels.values.toList(),
            onChanged: (v) => _followUp = v == null
                ? null
                : _employeeLabels.entries
                      .where((e) => e.value == v)
                      .map((e) => e.key)
                      .firstOrNull,
          ),
        ),
        // 11. Note
        full(
          FormFields(
            label: 'Note',
            controller: _notes,
            hintText: 'Enter Note...',
            maxLines: 3,
          ),
        ),
        // 12. Attachments
        full(_attachments(w)),
      ],
    );
  }

  Widget _attachments(double itemWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
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
    );
  }

  Future<void> _submit() async {
    if (_isEdit) {
      final perm = await PermissionService.getPermissions('Project Updation');
      if (!(perm?.canEdit ?? false)) {
        if (mounted) {
          FlushBar.show(
            context,
            'You do not have permission to edit project updations',
            isSuccess: false,
          );
        }
        return;
      }
      if (!mounted) return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_client == null || _project == null) {
      FlushBar.show(
        context,
        'Please select a master client and project',
        isSuccess: false,
      );
      return;
    }
    try {
      futureLoading(context);

      final attachments = List<FileModel>.from(_uploaded);
      if (_newFiles.isNotEmpty) {
        final data = await Future.wait(
          _newFiles.map((pf) async {
            final bytes = await platformFileToBytes(pf);
            return (bytes: bytes, fileName: pf.name);
          }),
        );
        final urls = await StorageService.uploadBytesInBatch(
          files: data,
          folder: StorageFolder.updationAttachments,
        );
        for (var i = 0; i < _newFiles.length; i++) {
          final pf = _newFiles[i];
          attachments.add(
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

      final model = ProjectUpdationModel(
        uid: _existing?.uid,
        updationNumber: _existing?.updationNumber,
        projectId: _project!.uid,
        projectName: _project!.label,
        clientId: _client!.uid,
        companyName: _client!.companyName,
        contactName: _client!.clientName,
        contactMobile: _client!.mobileNumber,
        title: _title.text.trim(),
        description: _description.text.trim(),
        requestedDate: _requested,
        status: _status,
        value: double.tryParse(_value.text.trim()),
        attachments: attachments,
        notes: _notes.text.trim(),
        followUp: _followUp,
        createdBy: _existing?.createdBy ?? await Spdb.getUser(),
        createdAt: _existing?.createdAt,
      );

      if (_isEdit) {
        await ProjectUpdationService.updateUpdation(
          uid: widget.uid!,
          updation: model,
        );
      } else {
        await ProjectUpdationService.createUpdation(updation: model);
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, true);
      FlushBar.show(
        context,
        _isEdit ? 'Project updation updated' : 'Project updation created',
        isSuccess: true,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}