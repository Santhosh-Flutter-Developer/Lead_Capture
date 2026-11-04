import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mime/mime.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/views/screens/project_updations/project_updation_form.dart'
    show masterClientLabel;
import '/theme/theme.dart';

class TicketCreate extends StatefulWidget {
  final List<EmployeeModel>? employees;

  const TicketCreate({super.key, this.employees});

  @override
  State<TicketCreate> createState() => _TicketCreateState();
}

class _TicketCreateState extends State<TicketCreate> {
  late Future _future;
  TicketPriority _priorityLevel = TicketPriority.medium;
  TicketCategory _category = TicketCategory.technicalSupport;
  TicketStatus _status = TicketStatus.open;
  TicketModeOfContact _modeOfContact = TicketModeOfContact.phone;
  final TextEditingController _ticketTitle = TextEditingController();
  final TextEditingController _ticketDescription = TextEditingController();
  final TextEditingController _deadline = TextEditingController();
  final TextEditingController _reminder = TextEditingController();
  final ScrollController _vScrollController = ScrollController();
  final ScrollController _vhScrollController = ScrollController();

  final List<String> _selectedAssignTo = [];
  final List<String> _selectedCreatedBy = [];
  final List<String> _selectedObservers = [];
  final List<String> _selectedParticipants = [];

  List<ProjectModel> _projectList = [];
  List<TaskModel> _taskList = [];
  String? _selectedProject;
  String? _selectedTask;

  List<ClientModel> _masterClients = [];
  ClientModel? _selectedMasterClient;
  // Bumped to rebuild the Project / Task dropdowns when their source changes.
  int _contextEpoch = 0;
  int _taskEpoch = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<PlatformFile> _selectedAttachments = [];
  DateTime? _selectedDeadline;
  DateTime? _selectedReminder;

  @override
  void initState() {
    super.initState();
    _future = _init();

    if (widget.employees != null && widget.employees!.isNotEmpty) {
      _selectedAssignTo.addAll(
        widget.employees!
            .where((e) => e.uid != null)
            .map((e) => e.uid!)
            .toList(),
      );
    }
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    _vhScrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _projectList = await ProjectService.getAllProjects();
      _taskList = await TaskService.getAllTasks();
      _masterClients = await ClientService.getMasterClients();
    } catch (e) {
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Back(color: AppColors.white),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Iconsax.ticket, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Create New Ticket",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Log a new support request",
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 900;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: FutureBuilder(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const WaitingLoading();
                    } else if (snapshot.hasError) {
                      return ErrorDisplay(error: snapshot.error.toString());
                    }

                    return Form(
                      key: _formKey,
                      child: Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 1400 : double.infinity,
                          ),
                          padding: const EdgeInsets.all(24.0),
                          child: isDesktop
                              ? _buildDesktopLayout()
                              : _buildMobileLayout(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildActionBottomBar(),
        );
      },
    );
  }

  /// DESKTOP LAYOUT: Two columns
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: Primary Info
        Expanded(
          flex: 2,
          child: Scrollbar(
            controller: _vScrollController,
            thumbVisibility: true,
            interactive: true,
            trackVisibility: true,
            radius: const Radius.circular(8),
            thickness: 8,
            child: SingleChildScrollView(
              controller: _vScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    title: "Ticket Details",
                    icon: Iconsax.document_text,
                    child: Column(
                      children: [
                        _buildMasterClientDropdown(),
 const SizedBox(height: 16),
                        _buildModeOfContactSelector(),
                        const SizedBox(height: 16),
                        FormFields(
                          controller: _ticketTitle,
                          label: "Ticket Title",
                          isRequired: true,
                          hintText: "Enter ticket title",
                          valid: (v) => Validation.commonValidation(
                            input: v,
                            label: "Ticket Title",
                            isReq: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDescriptionField(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: "Assignments",
                    icon: Iconsax.user_add,
                    child: _buildAssignmentGrid(),
                  ),
                  const SizedBox(height: 20),
                  _buildAttachmentSection(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // RIGHT COLUMN: Settings & Metadata
        Expanded(
          flex: 1,
          child: Scrollbar(
                    controller: _vhScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: SingleChildScrollView(
              controller: _vhScrollController,
              child: Column(
                children: [
                  _buildSectionCard(
                    title: "Context",
                    icon: Iconsax.hierarchy,
                    child: Column(
                      children: [
                        _buildProjectField(),
 const SizedBox(height: 16),
 _buildTaskField(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: "Ticket Settings",
                    icon: Iconsax.calendar_1,
                    child: Column(
                      children: [
                        _buildCategorySelector(),
                        const Divider(height: 32),
                        _buildStatusSelector(),
                        const Divider(height: 32),
                        _buildPrioritySelector(),
                        const Divider(height: 32),
                        _buildDeadlinePicker(),
                        const SizedBox(height: 16),
                        _buildReminderPicker(),
                      ],
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

  /// MOBILE LAYOUT: Single Column
  Widget _buildMobileLayout() {
    return Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: SingleChildScrollView(
        controller: _vScrollController,
        child: Column(
          children: [
            _buildSectionCard(
              title: "Ticket Details",
              icon: Iconsax.document_text,
              child: Column(
                children: [
                  _buildMasterClientDropdown(),
 const SizedBox(height: 16),
                  _buildModeOfContactSelector(),
                  const SizedBox(height: 16),
                  FormFields(
                    controller: _ticketTitle,
                    label: "Ticket Title",
                    isRequired: true,
                    hintText: "Enter ticket title",
                    valid: (v) => Validation.commonValidation(
                      input: v,
                      label: "Ticket Title",
                      isReq: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDescriptionField(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "Context",
              icon: Iconsax.hierarchy,
              child: Column(
                children: [
                  _buildProjectField(),
 const SizedBox(height: 16),
 _buildTaskField(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "Ticket Settings",
              icon: Iconsax.calendar_1,
              child: Column(
                children: [
                  _buildCategorySelector(),
                  const SizedBox(height: 16),
                  _buildStatusSelector(),
                  const SizedBox(height: 16),
                  _buildPrioritySelector(),
                  const SizedBox(height: 16),
                  _buildDeadlinePicker(),
                  const SizedBox(height: 16),
                  _buildReminderPicker(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "Assignments",
              icon: Iconsax.user_add,
              child: _buildAssignmentGrid(),
            ),
            const SizedBox(height: 16),
            _buildAttachmentSection(),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE COMPONENT BUILDERS ---

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.grey200, thickness: 1),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _ticketDescription,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: "Ticket Description",
        hintText: 'Describe the ticket details...',
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Priority Level",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: TicketPriority.values.map((priority) {
            final isSelected = _priorityLevel == priority;
            return FilterChip(
              label: Text(priority.label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _priorityLevel = priority;
                });
              },
              selectedColor: _getPriorityColor(priority).withValues(alpha: 0.2),
              checkmarkColor: _getPriorityColor(priority),
              labelStyle: TextStyle(
                color: isSelected
                    ? _getPriorityColor(priority)
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? _getPriorityColor(priority)
                    : Theme.of(context).colorScheme.outline,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Ticket Category",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TicketCategory>(
          initialValue: _category,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          items: TicketCategory.values.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category.label),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _category = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Ticket Status",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TicketStatus>(
          initialValue: _status,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          items: TicketStatus.values.map((status) {
            return DropdownMenuItem(value: status, child: Text(status.label));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _status = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildModeOfContactSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Mode of Contact",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TicketModeOfContact>(
          initialValue: _modeOfContact,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          items: TicketModeOfContact.values.map((mode) {
            return DropdownMenuItem(value: mode, child: Text(mode.label));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _modeOfContact = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAssignmentGrid() {
    return Column(
      children: [
        _requiredUsersField(
          label: 'Assign To',
          selected: _selectedAssignTo,
          initialValues: widget.employees ?? [],
        ),
        const SizedBox(height: 12),
        UsersListDropdown(
          label: 'Participants',
          onChangedList: (list) {
            _selectedParticipants.clear();
            _selectedParticipants.addAll(list.map((e) => e.uid!));
          },
        ),
        const SizedBox(height: 12),
        UsersListDropdown(
          label: 'Observers',
          onChangedList: (list) {
            _selectedObservers.clear();
            _selectedObservers.addAll(list.map((e) => e.uid!));
          },
        ),
        const SizedBox(height: 12),
        _requiredUsersField(label: 'Created By', selected: _selectedCreatedBy),
      ],
    );
  }

  // --- MASTER CLIENT / PROJECT / TASK (cascading) ---

  /// Projects that belong to the selected Master Client.
  List<ProjectModel> get _clientProjects {
    final id = _selectedMasterClient?.uid;
    if (id == null || id.isEmpty) return [];
    return _projectList
        .where((p) => p.client == id || p.clientId == id)
        .toList();
  }

  /// Tasks of the selected Master Client's projects. Narrowed to the chosen
  /// project once one is selected.
  List<TaskModel> get _clientTasks {
    final projectIds = _selectedProject != null
        ? {_selectedProject}
        : _clientProjects.map((p) => p.uid).toSet();
    if (projectIds.isEmpty) return [];
    return _taskList.where((t) => projectIds.contains(t.project)).toList();
  }

  /// label -> uid, adding a counter when two labels collide.
  Map<String, String> _uniqueOptions(
    Iterable<MapEntry<String, String>> entries,
  ) {
    final result = <String, String>{};
    for (final e in entries) {
      if (e.value.isEmpty) continue;
      var label = e.key;
      var n = 2;
      while (result.containsKey(label)) {
        label = '${e.key} ($n)';
        n++;
      }
      result[label] = e.value;
    }
    return result;
  }

  Map<String, String> get _projectOptions => _uniqueOptions(
    _clientProjects.map((p) => MapEntry(p.projectName, p.uid ?? '')),
  );

  Map<String, String> get _taskOptions => _uniqueOptions(
    _clientTasks.map((t) => MapEntry(t.taskName, t.uid ?? '')),
  );

  Map<String, ClientModel> get _masterClientOptions => {
    for (final c in _masterClients) masterClientLabel(c): c,
  };

  Widget _buildMasterClientDropdown() {
    final options = _masterClientOptions;
    return FormDropdownSearch(
      key: ValueKey('master_client_${_masterClients.length}'),
      label: 'Master Clients',
      isRequired: true,
      initialItem: _selectedMasterClient == null
          ? null
          : masterClientLabel(_selectedMasterClient!),
      items: options.keys.toList(),
      validator: (_) =>
          _selectedMasterClient == null ? '* Master Client is required' : null,
      onChanged: (val) {
        setState(() {
          _selectedMasterClient = val == null ? null : options[val as String];
          // Projects and tasks depend on the Master Client, so reset them.
          _selectedProject = null;
          _selectedTask = null;
          _contextEpoch++;
        });
      },
    );
  }

  Widget _buildProjectField() {
    final options = _projectOptions;
    final selectedLabel = _selectedProject == null
        ? null
        : options.entries
              .where((e) => e.value == _selectedProject)
              .map((e) => e.key)
              .firstOrNull;
    return FormDropdownSearch(
      key: ValueKey('project_${_contextEpoch}_${options.length}'),
      label: 'Project',
      isRequired: true,
      initialItem: selectedLabel,
      items: options.keys.toList(),
      validator: (_) => _selectedProject == null ? '* Project is required' : null,
      onChanged: (val) {
        setState(() {
          _selectedProject = val == null ? null : options[val as String];
          _selectedTask = null;
          _taskEpoch++;
        });
      },
    );
  }

  Widget _buildTaskField() {
    final options = _taskOptions;
    final selectedLabel = _selectedTask == null
        ? null
        : options.entries
              .where((e) => e.value == _selectedTask)
              .map((e) => e.key)
              .firstOrNull;
    return FormDropdownSearch(
      key: ValueKey('task_${_contextEpoch}_${_taskEpoch}_${options.length}'),
      label: 'Task',
      initialItem: selectedLabel,
      items: options.keys.toList(),
      onChanged: (val) {
        _selectedTask = val == null ? null : options[val as String];
      },
    );
  }

  /// A required multi-select user dropdown (red * + inline error message).
  Widget _requiredUsersField({
    required String label,
    required List<String> selected,
    List<dynamic> initialValues = const [],
  }) {
    return FormField<bool>(
      validator: (_) => selected.isEmpty ? '* $label is required' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UsersListDropdown(
            label: label,
            isRequired: true,
            initialValues: initialValues,
            onChangedList: (list) {
              selected.clear();
              selected.addAll(list.map((e) => e.uid! as String));
              if (field.hasError) field.validate();
            },
          ),
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
      ),
    );
  }

  Widget _buildDeadlinePicker() {
    return FormFields(
      controller: _deadline,
      readOnly: true,
      onTap: () async {
        var date = await datePicker(context);
        if (date != null) {
          var time = await pickTime(context, null);
          if (time != null) {
            setState(() {
              _selectedDeadline = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              _deadline.text = "${date.formatDate} ${time.format(context)}";
            });
          }
        }
      },
      hintText: 'Select deadline (optional)',
      suffixIcon: const Icon(Iconsax.calendar_edit),
    );
  }

  Widget _buildReminderPicker() {
    return FormFields(
      controller: _reminder,
      readOnly: true,
      onTap: () async {
        var date = await datePicker(context);
        if (date != null) {
          var time = await pickTime(context, null);
          if (time != null) {
            setState(() {
              _selectedReminder = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              _reminder.text = "${date.formatDate} ${time.format(context)}";
            });
          }
        }
      },
      hintText: 'Set reminder (optional)',
      suffixIcon: const Icon(Iconsax.notification),
    );
  }

  Widget _buildAttachmentSection() {
    return _buildSectionCard(
      title: "Attachments",
      icon: Iconsax.paperclip,
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              var files = await FilePick.pickFiles(context);
              if (files != null && files.isNotEmpty) {
                setState(() => _selectedAttachments.addAll(files));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  style: BorderStyle.none,
                ),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Iconsax.cloud_plus,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text("Click to upload or drag and drop"),
                  Text(
                    "Support for PDF, DOC, images up to 10MB",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (_selectedAttachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAttachments
                  .map(
                    (file) => AttachmentPill(
                      name: file.name,
                      onRemove: () =>
                          setState(() => _selectedAttachments.remove(file)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Text(
                  "Discard",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: _brandGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4364F7).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _submitForm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.add_circle,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Create Ticket",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);
        List<FileModel> attachments = [];

        if (_selectedAttachments.isNotEmpty) {
          final fileDataList = await Future.wait(
            _selectedAttachments.map((pf) async {
              final bytes = await platformFileToBytes(pf);
              return (bytes: bytes, fileName: pf.name);
            }),
          );
          List<String> urls = await StorageService.uploadBytesInBatch(
            files: fileDataList,
            folder: StorageFolder.ticketAttachments,
          );
          for (var i = 0; i < _selectedAttachments.length; i++) {
            final pf = _selectedAttachments[i];
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

        final ticket = CustomerTicketModel(
          masterClientId: _selectedMasterClient!.uid,
          clientName: masterClientLabel(_selectedMasterClient!),
          clientCompanyName: _selectedMasterClient!.companyName,
          modeOfContact: _modeOfContact,
          ticketTitle: _ticketTitle.text,
          ticketDescription: _ticketDescription.text,
          assignTo: _selectedAssignTo,
          createdBy: _selectedCreatedBy,
          observers: _selectedObservers,
          participants: _selectedParticipants,
          priorityLevel: _priorityLevel,
          deadline: _selectedDeadline,
          reminder: _selectedReminder,
          category: _category,
          status: _status,
          attachments: attachments,
          ticketCreatedBy: await Spdb.getUser(),
          project: _selectedProject,
          task: _selectedTask,
        );

        await TicketService.createTicket(ticket: ticket);
        Navigator.pop(context); // Pop loading
        Navigator.pop(context, true); // Close form
        FlushBar.show(context, 'Ticket created successfully', isSuccess: true);
      } catch (e, st) {
        Navigator.pop(context); // Pop loading
        ErrorService.recordError(e, st);
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }

  Color _getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return AppColors.info;
      case TicketPriority.medium:
        return AppColors.warning;
      case TicketPriority.high:
        return AppColors.danger;
      case TicketPriority.urgent:
        return Colors.red;
    }
  }
}