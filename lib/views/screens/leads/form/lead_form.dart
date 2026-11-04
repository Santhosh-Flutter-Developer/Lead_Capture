import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mime/mime.dart';
import '/models/models.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/views/screens/project_updations/project_updation_form.dart'
    show masterClientLabel;
import 'lead_form_ui.dart';

/// One flat form used for both creating ([uid] == null) and editing a lead.
///
/// The customer is picked from Master Client; company and contact details
/// are auto-filled (read only) from the selected client.
class LeadForm extends StatefulWidget {
  final String? uid;
  const LeadForm({super.key, this.uid});

  @override
  State<LeadForm> createState() => _LeadFormState();
}

class _LeadFormState extends State<LeadForm> {
  final ScrollController _vScroll = ScrollController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _leadName = TextEditingController();
  final _leadEmail = TextEditingController();
  final _leadValue = TextEditingController();
  final _notes = TextEditingController();
  final _projectName = TextEditingController();
  final _projectDescription = TextEditingController();
  final _company = TextEditingController();
  final _contact = TextEditingController();
  final _contactMobile = TextEditingController();

  late Future<void> _future;
  LeadModel? _existing;

  List<ClientModel> _clients = [];
  ClientModel? _client;
  List<LeadSourceModel> _sources = [];
  LeadSourceModel? _source;
  List<LeadCategoryModel> _categories = [];
  LeadCategoryModel? _category;
  List<LeadPriorityModel> _priorities = [];
  LeadPriorityModel? _priority;
  List<LeadStatusModel> _statuses = [];
  LeadStatusModel? _status;

  // Follow Up (optional): the employee who owns the follow-up. When set,
  // only that employee and admins can see this lead.
  List<EmployeeModel> _employees = [];
  Map<String, String> _employeeLabels = {}; // uid -> label
  String? _followUp; // employee uid

  final List<PlatformFile> _newFiles = [];
  List<FileModel> _uploaded = [];

  bool get _isEdit => (widget.uid ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    for (final c in [
      _leadName,
      _leadEmail,
      _leadValue,
      _notes,
      _projectName,
      _projectDescription,
      _company,
      _contact,
      _contactMobile,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload({
    bool clients = false,
    bool sources = false,
    bool categories = false,
    bool priorities = false,
    bool statuses = false,
  }) async {
    if (clients) _clients = await ClientService.getMasterClients();
    if (sources) _sources = await LeadSourceService.getAllLeadSource();
    if (categories) {
      _categories = await LeadCategoryService.getAllLeadCategories();
    }
    if (priorities) {
      _priorities = await LeadPriorityService.getAllLeadPriority();
    }
    if (statuses) _statuses = await LeadStatusService.getAllLeadStatus();
  }

  Future<void> _init() async {
    try {
      await _reload(
        clients: true,
        sources: true,
        categories: true,
        priorities: true,
        statuses: true,
      );

      try {
        _employees = await FollowUpAccess.employees();
        _employeeLabels = FollowUpAccess.labelsByUid(_employees);
      } catch (_) {
        // Follow Up is optional: never block the form if it can't load.
      }

      if (_isEdit) {
        final lead = await LeadService.getLead(uid: widget.uid!);
        _existing = lead;
        _followUp = lead.followUp;
        _leadName.text = lead.leadName;
        _leadEmail.text = lead.leadEmail;
        _leadValue.text = lead.leadValue == 0 ? '' : lead.leadValue.toString();
        _notes.text = lead.notes;
        _projectName.text = lead.projectName ?? '';
        _projectDescription.text = lead.projectDescription ?? '';
        _uploaded = List<FileModel>.from(lead.attachments);
        _source = lead.leadSource.name.isEmpty ? null : lead.leadSource;

        _client = _clients.cast<ClientModel?>().firstWhere(
          (c) => c?.uid == lead.clientId,
          orElse: () => null,
        );
        if (_client != null) {
          _syncClientFields();
        } else {
          // Legacy lead created before Master Client: show what it stored.
          _company.text = lead.companyName ?? '';
          _contact.text = lead.clientName ?? '';
          _contactMobile.text = lead.clientMobile ?? '';
        }

        _category = _categories.cast<LeadCategoryModel?>().firstWhere(
          (c) => c?.uid == lead.leadCategory || c?.name == lead.leadCategory,
          orElse: () => null,
        );
        _priority = _priorities.cast<LeadPriorityModel?>().firstWhere(
          (p) => p?.uid == lead.leadPriority || p?.name == lead.leadPriority,
          orElse: () => null,
        );
        _status = _statuses.cast<LeadStatusModel?>().firstWhere(
          (s) => s?.uid == lead.leadStatus || s?.name == lead.leadStatus,
          orElse: () => null,
        );
      } else if (_statuses.isNotEmpty) {
        _status = _statuses.firstWhere(
          (s) => s.name.toLowerCase() == 'new',
          orElse: () => _statuses.first,
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  void _syncClientFields() {
    _company.text = _client?.companyName ?? '';
    _contact.text = _client?.clientName ?? '';
    _contactMobile.text = _client?.mobileNumber ?? '';
  }

  /// A dropdown with a "+" button beside it to add a new value in place.
  Widget _withPlus({
    required Widget dropdown,
    required Future<dynamic> Function() onAdd,
    required Future<void> Function(dynamic result) onAdded,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: dropdown),
        const SizedBox(width: 8.0),
        InkWell(
          onTap: () async {
            final val = await onAdd();
            if (val is Map && val['status'] == true) {
              await onAdded(val);
              if (mounted) setState(() {});
            }
          },
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
        ),
      ],
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
                  title: _isEdit ? 'Edit Leads' : 'Create Leads',
                  subtitle: 'Pick a master client and capture the lead',
                  icon: Iconsax.personalcard,
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
                            title: 'Lead Details',
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

    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      children: [
        box(
          _withPlus(
            dropdown: FormDropdownSearch(
              key: ValueKey('client_${_clients.length}_${_client?.uid}'),
              label: 'Master Client',
              isRequired: true,
              initialItem: _client == null ? null : masterClientLabel(_client!),
              items: _clients.map(masterClientLabel).toList(),
              onChanged: (v) => setState(() {
                _client = _clients.cast<ClientModel?>().firstWhere(
                  (c) => c != null && masterClientLabel(c) == v,
                  orElse: () => null,
                );
                _syncClientFields();
              }),
              validator: (v) => v == null ? '* Required' : null,
            ),
            onAdd: () async {
              dynamic val;
              final form = const MasterClientForm();
              if (kIsMobile) {
                val = await Sheet.showSheet(context, widget: form);
              } else {
                val = await GeneralDialog.showRTLSheet(context, form);
              }
              return val;
            },
            onAdded: (val) async {
              await _reload(clients: true);
              if (val['client'] is ClientModel) {
                _client = val['client'] as ClientModel;
                _syncClientFields();
              }
            },
          ),
        ),
        box(FormFields(label: 'Company', controller: _company, readOnly: true)),
        box(
          FormFields(label: 'Contact Name', controller: _contact, readOnly: true),
        ),
        box(
          FormFields(
            label: 'Contact Mobile',
            controller: _contactMobile,
            readOnly: true,
          ),
        ),
        box(
          FormFields(
            label: 'Lead Name',
            controller: _leadName,
            hintText: 'e.g. Website redesign',
            isRequired: true,
            valid: (v) => (v == null || v.trim().isEmpty) ? '* Required' : null,
          ),
        ),
        box(
          FormFields(
            label: 'Lead Email',
            controller: _leadEmail,
            hintText: 'e.g. email@example.com',
            keyboardType: TextInputType.emailAddress,
            valid: (input) {
              if (input == null || input.isEmpty) return null;
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
        ),
        box(
          _withPlus(
            dropdown: FormDropdownSearch(
              key: ValueKey('source_${_sources.length}_${_source?.uid}'),
              label: 'Lead Source',
              isRequired: true,
              initialItem: _source?.name,
              items: _sources.map((e) => e.name).toList(),
              onChanged: (v) => _source = _sources
                  .cast<LeadSourceModel?>()
                  .firstWhere((s) => s?.name == v, orElse: () => null),
              validator: (v) => v == null ? '* Required' : null,
            ),
            onAdd: () async {
              dynamic val;
              if (kIsMobile) {
                val = await Sheet.showSheet(context, widget: const LeadSourceCreate());
              } else {
                val = await GeneralDialog.showRTLSheet(context, const LeadSourceCreate());
              }
              return val;
            },
            onAdded: (_) => _reload(sources: true),
          ),
        ),
        box(
          _withPlus(
            dropdown: FormDropdownSearch(
              key: ValueKey('category_${_categories.length}_${_category?.uid}'),
              label: 'Lead Category',
              isRequired: true,
              initialItem: _category?.name,
              items: _categories.map((e) => e.name).toList(),
              onChanged: (v) => _category = _categories
                  .cast<LeadCategoryModel?>()
                  .firstWhere((c) => c?.name == v, orElse: () => null),
              validator: (v) => v == null ? '* Required' : null,
            ),
            onAdd: () async {
              dynamic val;
              if (kIsMobile) {
                val = await Sheet.showSheet(context, widget: const LeadCategoryCreate());
              } else {
                val = await GeneralDialog.showRTLSheet(context, const LeadCategoryCreate());
              }
              return val;
            },
            onAdded: (_) => _reload(categories: true),
          ),
        ),
        box(
          _withPlus(
            dropdown: FormDropdownSearch(
              key: ValueKey('priority_${_priorities.length}_${_priority?.uid}'),
              label: 'Lead Priority',
              isRequired: true,
              initialItem: _priority?.name,
              items: _priorities.map((e) => e.name).toList(),
              onChanged: (v) => _priority = _priorities
                  .cast<LeadPriorityModel?>()
                  .firstWhere((p) => p?.name == v, orElse: () => null),
              validator: (v) => v == null ? '* Required' : null,
            ),
            onAdd: () async {
              dynamic val;
              if (kIsMobile) {
                val = await Sheet.showSheet(context, widget: const LeadPriorityCreate());
              } else {
                val = await GeneralDialog.showRTLSheet(context, const LeadPriorityCreate());
              }
              return val;
            },
            onAdded: (_) => _reload(priorities: true),
          ),
        ),
        box(
          _withPlus(
            dropdown: FormDropdownSearch(
              key: ValueKey('status_${_statuses.length}_${_status?.uid}'),
              label: 'Status',
              isRequired: true,
              initialItem: _status?.name,
              items: _statuses.map((e) => e.name).toList(),
              onChanged: (v) => _status = _statuses
                  .cast<LeadStatusModel?>()
                  .firstWhere((s) => s?.name == v, orElse: () => null),
              validator: (v) => v == null ? '* Required' : null,
            ),
            onAdd: () async {
              dynamic val;
              if (kIsMobile) {
                val = await Sheet.showSheet(context, widget: const LeadStatusCreate());
              } else {
                val = await GeneralDialog.showRTLSheet(context, const LeadStatusCreate());
              }
              return val;
            },
            onAdded: (_) => _reload(statuses: true),
          ),
        ),
        box(
          FormFields(
            label: 'Lead Value',
            controller: _leadValue,
            hintText: 'Enter Amount',
            keyboardType: TextInputType.number,
            valid: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return double.tryParse(v.trim()) == null ? 'Enter a number' : null;
            },
          ),
        ),
        box(
          FormFields(
            label: 'Project Name',
            controller: _projectName,
            hintText: 'Project this lead is about',
          ),
        ),
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
        full(
          FormFields(
            label: 'Project Description',
            controller: _projectDescription,
            hintText: 'Describe the project',
            maxLines: 3,
          ),
        ),
        full(
          FormFields(
            label: 'Note',
            controller: _notes,
            hintText: 'Enter Note...',
            maxLines: 3,
          ),
        ),
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
      // Never save without the role's Edit permission, even if this form was
      // opened from a screen that forgot to hide its button.
      final perm = await PermissionService.getPermissions('Leads');
      if (!(perm?.canEdit ?? false)) {
        if (mounted) {
          FlushBar.show(
            context,
            'You do not have permission to edit leads',
            isSuccess: false,
          );
        }
        return;
      }
      if (!mounted) return;
    }
    if (_existing?.leadsConverted == true) {
      FlushBar.show(
        context,
        'A converted lead can no longer be edited',
        isSuccess: false,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_client == null || _source == null) {
      FlushBar.show(context, 'Please complete the required fields', isSuccess: false);
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
          folder: StorageFolder.leadAttachments,
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

      final c = _client!;
      final workflow = await EmployeeService.getUserWorkflow();

      final fields = (
        leadName: _leadName.text.trim(),
        leadEmail: _leadEmail.text.trim(),
        value: double.tryParse(_leadValue.text.trim()) ?? 0.0,
      );

      late final String leadUid;
      if (_isEdit) {
        leadUid = widget.uid!;
        final updated = _existing!.copyWith(
          leadName: fields.leadName,
          leadEmail: fields.leadEmail,
          leadSource: _source!,
          leadCategory: _category?.uid ?? '',
          leadPriority: _priority?.uid ?? '',
          leadValue: fields.value,
          leadStatus: _status?.uid ?? '',
          notes: _notes.text.trim(),
          attachments: attachments,
          companyName: c.companyName,
          companyMobile: c.officePhoneNo,
          companyAddress: c.companyAddress,
          companyZipCode: c.postalCode,
          clientName: c.clientName,
          clientMobile: c.mobileNumber,
          clientId: c.uid,
          projectName: _projectName.text.trim(),
          projectDescription: _projectDescription.text.trim(),
          followUp: _followUp,
          clearFollowUp: _followUp == null,
          workflow: workflow,
        );
        await LeadService.updateLead(uid: leadUid, lead: updated);
      } else {
        final lead = LeadModel(
          leadName: fields.leadName,
          leadEmail: fields.leadEmail,
          leadSource: _source!,
          leadCategory: _category?.uid ?? '',
          leadPriority: _priority?.uid ?? '',
          leadValue: fields.value,
          leadStatus: _status?.uid ?? '',
          notes: _notes.text.trim(),
          attachments: attachments,
          companyName: c.companyName,
          companyMobile: c.officePhoneNo,
          companyAddress: c.companyAddress,
          companyZipCode: c.postalCode,
          clientName: c.clientName,
          clientMobile: c.mobileNumber,
          clientId: c.uid,
          projectName: _projectName.text.trim(),
          projectDescription: _projectDescription.text.trim(),
          followUp: _followUp,
          createdBy: await Spdb.getUser(),
          workflow: workflow,
        );
        leadUid = await LeadService.createLead(lead: lead);
      }

      // Status "Completed" -> a Deal is created automatically in "New".
      final converted = await LeadService.convertIfCompleted(leadUid: leadUid);

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, true);
      FlushBar.show(
        context,
        converted
            ? 'Lead saved and a deal was added to the New stage'
            : (_isEdit ? 'Lead updated successfully' : 'Lead created successfully'),
        isSuccess: true,
      );
    } catch (e, st) {
      debugPrint('$e, $st');
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}