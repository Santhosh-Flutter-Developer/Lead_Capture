import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mime/mime.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class TaskCreate extends StatefulWidget {
  final List<EmployeeModel>? employees;

  const TaskCreate({super.key, this.employees});

  @override
  State<TaskCreate> createState() => _TaskCreateState();
}

class _TaskCreateState extends State<TaskCreate> {
  late Future _future;
  bool _highPriority = false;
  final bool _taskStatusSummary = false;
  final TextEditingController _taskName = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _deadLine = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _reminder = TextEditingController();

  List<ProjectModel> _projectList = [];
  List<EmployeeModel> _employeeList = [];
  List<TaskModel> _taskList = [];

  final List<String> _selectedAssignees = [];
  final List<String> _selectedCreatedBy = [];
  final List<String> _selectedObservers = [];
  final List<String> _selectedParticipants = [];

  String? _selectedProject;
  String? _selectedLead;
  String? _selectedSubTaskOf;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _vScrollController = ScrollController();
  final ScrollController _vhScrollController = ScrollController();

  final List<PlatformFile> _selectedAttachments = [];
  DateTime? _selectedDeadLine;
  DateTime? _selectedReminder;
  bool _deadlineRequired = true;

  @override
  void initState() {
    super.initState();
    _future = _init();

    if (widget.employees != null && widget.employees!.isNotEmpty) {
      _selectedAssignees.addAll(
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
      _employeeList = await EmployeeService.getAllEmployees();
      _taskList = await TaskService.getAllTasks();
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
            child: const Icon(
              Iconsax.task_square,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Create New Task",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Plan and assign a new piece of work",
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
                            maxWidth: isDesktop ? 1200 : double.infinity,
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
                    title: "Task Details",
                    icon: Iconsax.document_text,
                    child: Column(
                      children: [
                        _buildTaskNameField(),
                        const SizedBox(height: 20),
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
                    title: "Planning",
                    icon: Iconsax.calendar_1,
                    child: Column(
                      children: [
                        _buildPriorityToggle(),
                        const Divider(height: 32),
                        _buildDeadlinePicker(),
                        const SizedBox(height: 16),
                        _buildReminderPicker(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    title: "Context",
                    icon: Iconsax.hierarchy,
                    child: _buildContextFields(),
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
              title: "Task Details",
              icon: Iconsax.document_text,
              child: Column(
                children: [
                  _buildTaskNameField(),
                  const SizedBox(height: 16),
                  _buildDescriptionField(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: "Planning",
              icon: Iconsax.calendar_1,
              child: Column(
                children: [
                  _buildPriorityToggle(),
                  _buildDeadlinePicker(),
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
            _buildSectionCard(
              title: "Context",
              icon: Iconsax.hierarchy,
              child: _buildContextFields(),
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

  Widget _buildTaskNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _requiredLabel('Task Title'),
        const SizedBox(height: 4),
        _buildTaskNameInput(),
      ],
    );
  }

  Widget _buildTaskNameInput() {
    return TextFormField(
      controller: _taskName,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Enter Task Title...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      validator: (v) => Validation.commonValidation(
        input: v,
        label: 'Task Title',
        isReq: true,
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _description,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: 'Describe the requirements and objectives...',
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

  Widget _buildPriorityToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _highPriority
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.priority_high,
                size: 16,
                color: _highPriority
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                "High Priority",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _highPriority
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: _highPriority,
          activeTrackColor: Theme.of(context).colorScheme.errorContainer,
          onChanged: (val) => setState(() => _highPriority = val),
        ),
      ],
    );
  }

  Widget _buildAssignmentGrid() {
    return Column(
      children: [
        _requiredUsersDropdown(
          label: 'Assign To',
          initialValues: widget.employees ?? const [],
          selected: _selectedAssignees,
          onChanged: (list) {
            _selectedAssignees.clear();
            _selectedAssignees.addAll(list.map((e) => e.uid!));
          },
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
        _requiredUsersDropdown(
          label: 'Created By',
          selected: _selectedCreatedBy,
          onChanged: (list) {
            _selectedCreatedBy.clear();
            _selectedCreatedBy.addAll(list.map((e) => e.uid!));
          },
        ),
      ],
    );
  }

  /// Small field label with a red "*" for required fields.
  Widget _requiredLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          ' *',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.danger,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Required multi-select users dropdown (red "*" + inline error when
  /// nothing is selected). [selected] is the list the form submits.
  Widget _requiredUsersDropdown({
    required String label,
    required List<String> selected,
    required void Function(List<dynamic>) onChanged,
    List<dynamic> initialValues = const [],
  }) {
    return FormField<List<String>>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) => selected.isEmpty ? '$label is required' : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UsersListDropdown(
              label: label,
              isRequired: true,
              initialValues: initialValues,
              onChangedList: (list) {
                onChanged(list);
                field.didChange(List<String>.from(selected));
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
        );
      },
    );
  }

  // --- CONTEXT (Project / Subtask / Lead / Tags) ---

  String? _leadName(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return _employeeList
        .where((e) => e.uid == uid)
        .map((e) => e.name)
        .firstOrNull;
  }

  /// Picking a project auto-fills its Project Lead into the Lead field.
  void _onProjectChanged(dynamic val) {
    if (val == null) {
      setState(() {
        _selectedProject = null;
        _selectedLead = null;
      });
      return;
    }
    final project = _projectList.firstWhere((e) => e.projectName == val);
    setState(() {
      _selectedProject = project.uid;
      _selectedLead = project.projectOwner.isNotEmpty
          ? project.projectOwner
          : null;
    });
  }

  Widget _buildContextFields() {
    return Column(
      children: [
        _buildDropdownField(
          "Project",
          _projectList.map((e) => e.projectName).toList(),
          _onProjectChanged,
          isRequired: true,
          validator: (_) => (_selectedProject == null || _selectedProject!.isEmpty)
              ? 'Project is required'
              : null,
          initialItem: _selectedProject != null
              ? _projectList
                    .where((e) => e.uid == _selectedProject)
                    .map((e) => e.projectName)
                    .firstOrNull
              : null,
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          "Subtask of",
          _taskList.map((e) => e.taskName).toList(),
          (val) {
            _selectedSubTaskOf = val == null
                ? null
                : _taskList.firstWhere((e) => e.taskName == val).uid;
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          "Project Lead",
          _employeeList.map((e) => e.name).toList(),
          (val) {
            _selectedLead = val == null
                ? null
                : _employeeList.firstWhere((e) => e.name == val).uid;
          },
          initialItem: _leadName(_selectedLead),
          fieldKey: ValueKey('lead_${_selectedLead ?? ''}'),
        ),
        const SizedBox(height: 16),
        _buildTagsField(),
      ],
    );
  }

  Widget _buildDeadlinePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _deadlineRequired,
              onChanged: (val) => setState(() => _deadlineRequired = val!),
            ),
            const Text("Deadline Required"),
          ],
        ),
        FormFields(
          enabled: _deadlineRequired,
          controller: _deadLine,
          readOnly: true,
          onTap: () async {
            var date = await datePicker(context);
            if (date != null) {
              var time = await pickTime(context, null);
              if (time != null) {
                setState(() {
                  _selectedDeadLine = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                  _deadLine.text = "${date.formatDate} ${time.format(context)}";
                });
              }
            }
          },
          hintText: 'Select date & time',
          suffixIcon: const Icon(Iconsax.calendar_edit),
        ),
      ],
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
      hintText: 'Set Reminder',
      suffixIcon: const Icon(Iconsax.notification),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    Function(dynamic) onChanged, {
    bool isRequired = false,
    String? Function(dynamic)? validator,
    String? initialItem,
    Key? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (isRequired)
              Text(
                ' *',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FormDropdownSearch(
          key: fieldKey,
          items: items,
          onChanged: onChanged,
          validator: validator,
          initialItem: initialItem,
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    return FormFields(
      hintText: 'Tag1, Tag2...',
      controller: _tags,
      label: 'Tags',
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
                        "Create Task",
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
            folder: StorageFolder.taskAttachments,
          );
          for (var i = 0; i < _selectedAttachments.length; i++) {
            final pf = _selectedAttachments[i];
            final ext = pf.extension ?? '';
            final mimeType = lookupMimeType(pf.name) ?? '';
            attachments.add(
              FileModel(
                name: pf.name,
                extension: ext,
                size: pf.size,
                url: urls[i],
                mimeType: mimeType,
              ),
            );
          }
        }

        final task = TaskModel(
          taskName: _taskName.text,
          description: _description.text,
          project: _selectedProject,
          subTaskOf: _selectedSubTaskOf,
          lead: _selectedLead,
          deadline: _selectedDeadLine,
          deadlineRequired: _deadlineRequired,
          highPriority: _highPriority,
          statusSummaryRequired: _taskStatusSummary,
          assignees: _selectedAssignees,
          createdBy: _selectedCreatedBy,
          observers: _selectedObservers,
          participants: _selectedParticipants,
          reminder: _selectedReminder,
          tags: _tags.text.split(','),
          attachments: attachments,
          taskCreatedBy: await Spdb.getUser(),
        );

        await TaskService.createTask(task: task);
        Navigator.pop(context); // Pop loading
        Navigator.pop(context, true); // Close form
        FlushBar.show(context, 'Task created successfully', isSuccess: true);
      } catch (e, st) {
        Navigator.pop(context); // Pop loading
        ErrorService.recordError(e, st);
        FlushBar.show(context, e.toString(), isSuccess: false);
      }
    }
  }
}