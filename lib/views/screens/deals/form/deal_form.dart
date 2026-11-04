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
import 'deal_form_ui.dart';

/// One flat form used for both creating ([uid] == null) and editing a deal.
///
/// A client is captured once in Master Client; any number of deals
/// (projects) can then be added for it. Company / contact fields are
/// auto-filled and read only.
class DealForm extends StatefulWidget {
  final String? uid;
  const DealForm({super.key, this.uid});

  @override
  State<DealForm> createState() => _DealFormState();
}

class _DealFormState extends State<DealForm> {
  final ScrollController _vScroll = ScrollController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _projectName = TextEditingController();
  final _dealEmail = TextEditingController();
  final _dealValue = TextEditingController();
  final _projectDescription = TextEditingController();
  final _notes = TextEditingController();
  final _company = TextEditingController();
  final _contact = TextEditingController();
  final _contactMobile = TextEditingController();

  late Future<void> _future;
  DealModel? _existing;

  List<ClientModel> _clients = [];
  ClientModel? _client;
  List<DealStatusModel> _statuses = [];
  DealStatusModel? _status;

  // Follow Up (optional): only this employee and admins can see the deal.
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
      _projectName,
      _dealEmail,
      _dealValue,
      _projectDescription,
      _notes,
      _company,
      _contact,
      _contactMobile,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _clients = await ClientService.getMasterClients();
      _statuses = await DealStatusService.getAllDealStatus();
      try {
        _employees = await FollowUpAccess.employees();
        _employeeLabels = FollowUpAccess.labelsByUid(_employees);
      } catch (_) {
        // Follow Up is optional: never block the form if it can't load.
      }

      if (_isEdit) {
        final deal = await DealService.getDeal(uid: widget.uid!);
        _existing = deal;
        _followUp = deal.followUp;

        if (deal.isLocked) {
          if (mounted) {
            FlushBar.show(
              context,
              'This deal is locked and cannot be edited',
              isSuccess: false,
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) Navigator.pop(context);
            });
          }
          return;
        }

        _projectName.text = (deal.projectName ?? '').isNotEmpty
            ? deal.projectName!
            : deal.dealName;
        _dealEmail.text = deal.dealEmail;
        _dealValue.text = deal.dealValue == 0 ? '' : deal.dealValue.toString();
        _projectDescription.text = deal.projectDescription ?? '';
        _notes.text = deal.notes;
        _uploaded = List<FileModel>.from(deal.attachments);

        _client = _clients.cast<ClientModel?>().firstWhere(
          (c) => c?.uid == deal.clientId,
          orElse: () => null,
        );
        if (_client != null) {
          _syncClientFields();
        } else {
          _company.text = deal.companyName ?? '';
          _contact.text = deal.clientName ?? '';
          _contactMobile.text = deal.clientMobile ?? '';
        }

        _status = _statuses.cast<DealStatusModel?>().firstWhere(
          (s) => s?.uid == deal.dealStatus,
          orElse: () => null,
        );
      } else if (_statuses.isNotEmpty) {
        // Default status: New
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

  Widget _plus(VoidCallback onTap) {
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

  Future<dynamic> _open(Widget form) {
    if (kIsMobile) return Sheet.showSheet(context, widget: form);
    return GeneralDialog.showRTLSheet(context, form);
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
                DealFormUI.header(
                  context,
                  title: _isEdit ? 'Edit Deals' : 'Create Deals',
                  subtitle: 'Add a project (deal) for a master client',
                  icon: Iconsax.briefcase,
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
                          child: DealFormUI.sectionCard(
                            context,
                            title: 'Deal Details',
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
        bottomNavigationBar: DealFormUI.bottomBar(
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
      runSpacing: 10,
      children: [
        box(
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FormDropdownSearch(
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
              ),
              const SizedBox(width: 8),
              _plus(() async {
                final val = await _open(const MasterClientForm());
                if (val is Map && val['status'] == true) {
                  _clients = await ClientService.getMasterClients();
                  if (val['client'] is ClientModel) {
                    _client = val['client'] as ClientModel;
                    _syncClientFields();
                  }
                  if (mounted) setState(() {});
                }
              }),
            ],
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
            label: 'Project Name',
            controller: _projectName,
            hintText: 'e.g. Website redesign',
            isRequired: true,
            valid: (v) => (v == null || v.trim().isEmpty) ? '* Required' : null,
          ),
        ),
        box(
          FormFields(
            label: 'Deal Email',
            controller: _dealEmail,
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
          FormFields(
            label: 'Deal Value',
            controller: _dealValue,
            keyboardType: TextInputType.number,
            hintText: 'Enter amount',
            valid: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return double.tryParse(v.trim()) == null ? 'Enter a number' : null;
            },
          ),
        ),
        box(
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FormDropdownSearch(
                  key: ValueKey('status_${_statuses.length}_${_status?.uid}'),
                  label: 'Status',
                  initialItem: _status?.name,
                  items: _statuses.map((e) => e.name).toList(),
                  onChanged: (v) => _status = _statuses
                      .cast<DealStatusModel?>()
                      .firstWhere((s) => s?.name == v, orElse: () => null),
                ),
              ),
              const SizedBox(width: 8),
              _plus(() async {
                final val = await _open(const DealStatusCreate());
                if (val is Map && val['status'] == true) {
                  _statuses = await DealStatusService.getAllDealStatus();
                  if (mounted) setState(() {});
                }
              }),
            ],
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
            hintText: 'Enter note...',
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
      final perm = await PermissionService.getPermissions('Deals');
      if (!(perm?.canEdit ?? false)) {
        if (mounted) {
          FlushBar.show(
            context,
            'You do not have permission to edit deals',
            isSuccess: false,
          );
        }
        return;
      }
      if (!mounted) return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_client == null) {
      FlushBar.show(context, 'Please select a master client', isSuccess: false);
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
          folder: StorageFolder.dealAttachments,
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
      final project = _projectName.text.trim();
      final value = double.tryParse(_dealValue.text.trim()) ?? 0.0;

      if (_isEdit) {
        final updated = _existing!.copyWith(
          dealName: project,
          dealEmail: _dealEmail.text.trim(),
          dealValue: value,
          dealStatus: _status?.uid,
          notes: _notes.text.trim(),
          attachments: attachments,
          companyName: c.companyName,
          companyMobile: c.officePhoneNo,
          companyAddress: c.companyAddress,
          companyZipCode: c.postalCode,
          clientName: c.clientName,
          clientMobile: c.mobileNumber,
          clientId: c.uid,
          projectName: project,
          projectDescription: _projectDescription.text.trim(),
          followUp: _followUp,
          clearFollowUp: _followUp == null,
        );
        await DealService.updateDeal(uid: widget.uid!, deal: updated);
      } else {
        final deal = DealModel(
          dealName: project,
          dealEmail: _dealEmail.text.trim(),
          dealValue: value,
          allowFollowUp: true,
          dealStatus: _status?.uid,
          notes: _notes.text.trim(),
          attachments: attachments,
          companyName: c.companyName,
          companyMobile: c.officePhoneNo,
          companyAddress: c.companyAddress,
          companyZipCode: c.postalCode,
          clientName: c.clientName,
          clientMobile: c.mobileNumber,
          clientId: c.uid,
          projectName: project,
          projectDescription: _projectDescription.text.trim(),
          followUp: _followUp,
          createdBy: await Spdb.getUser(),
          workFlow: [await Spdb.getUid() ?? ''],
        );
        await DealService.createDeal(deal: deal);
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, true);
      FlushBar.show(
        context,
        _isEdit ? 'Deal updated successfully' : 'Deal created successfully',
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