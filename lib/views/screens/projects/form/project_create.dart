import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/screens/project_updations/project_updation_form.dart'
    show masterClientLabel;

class ProjectCreate extends StatefulWidget {
  const ProjectCreate({super.key});

  @override
  State<ProjectCreate> createState() => _ProjectCreateState();
}

class _ProjectCreateState extends State<ProjectCreate> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController =
      TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _projectCodeController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  DateTime? _selectedDeadlineDate;

  List<EmployeeModel> _employeesList = [];
  List<ClientModel> _masterClients = [];
  final TextEditingController _masterClientController =
      TextEditingController();
  List<DealModel> _dealList = [];
  List<ProjectModel> _existingProjects = [];
  String? _selectedDealId;
  String? _selectedProjectName;
  String? _selectedMasterClient;
  String? _selectedProjectOwner;
  String? _selectedTeamLead;
  final List<String> _selectedProjectMembers = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late Future _future;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    try {
      _masterClients.clear();
      _employeesList.clear();
      _dealList.clear();
      _employeesList = await EmployeeService.getAllEmployees();
      _masterClients = await ClientService.getMasterClients();
      _dealList = await DealService.getAllDeals();
      _existingProjects = await ProjectService.getAllProjects();
      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      if (!mounted) return;
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    _clientNameController.dispose();
    _masterClientController.dispose();
    _projectCodeController.dispose();
    _categoryController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _deadlineController.dispose();
    _tagsController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  /// Project name stored on a deal (falls back to the legacy dealName).
  String _dealProjectName(DealModel deal) =>
      (deal.projectName ?? '').trim().isNotEmpty
      ? deal.projectName!.trim()
      : deal.dealName.trim();

  String _normName(String? v) => (v ?? '').trim().toLowerCase();

  /// Projects that already exist (this project itself is ignored in Edit).
  Iterable<ProjectModel> get _otherProjects => _existingProjects.where(
    (p) => true,
  );

  /// A deal is "already created" when a project is linked to it, or a
  /// project with the same name exists.
  bool _isDealUsed(DealModel d) {
    final name = _normName(_dealProjectName(d));
    return _otherProjects.any(
      (p) =>
          ((p.dealId ?? '').isNotEmpty && p.dealId == d.uid) ||
          _normName(p.projectName) == name,
    );
  }

  /// Deals that still have no project created.
  List<DealModel> get _availableDeals =>
      _dealList.where((d) => !_isDealUsed(d)).toList();

  /// Dropdown labels built from the created Deals' project names.
  /// If two deals share a project name, the company/client name is
  /// appended so every label stays unique.
  Map<String, DealModel> get _dealOptions {
    final Map<String, int> counts = {};
    for (final d in _availableDeals) {
      final name = _dealProjectName(d);
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final Map<String, DealModel> options = {};
    for (final d in _availableDeals) {
      final name = _dealProjectName(d);
      if (name.isEmpty) continue;
      var label = name;
      if ((counts[name] ?? 0) > 1) {
        final owner = (d.companyName ?? '').trim().isNotEmpty
            ? d.companyName!.trim()
            : (d.clientName ?? '').trim();
        if (owner.isNotEmpty) label = '$name - $owner';
      }
      options[label] = d;
    }
    return options;
  }

  void _onProjectSelected(dynamic value) {
    if (value == null) {
      // Cleared: reset the name and the auto-filled description.
      _selectedProjectName = null;
      _projectNameController.clear();
      _projectDescriptionController.clear();
      _selectedDealId = null;
      _setMasterClient(null);
      setState(() {});
      return;
    }

    final deal = _dealOptions[value as String];
    if (deal == null) return;

    _selectedProjectName = _dealProjectName(deal);
    _projectNameController.text = _selectedProjectName!;
    // Auto-fetch the description saved on the Deal.
    _projectDescriptionController.text = deal.projectDescription ?? '';
    _selectedDealId = deal.uid;
    // Auto-select the Master Client of this deal.
    _setMasterClient(
      deal.clientId,
      fallbackName: deal.companyName ?? deal.clientName,
    );
    setState(() {});
  }

  /// Master Client is read-only: it is taken from the selected deal.
  void _setMasterClient(String? uid, {String? fallbackName}) {
    final id = (uid ?? '').trim();
    if (id.isEmpty) {
      _selectedMasterClient = null;
      _masterClientController.clear();
      return;
    }
    final c = _masterClients.where((e) => e.uid == id).firstOrNull;
    _selectedMasterClient = id;
    _masterClientController.text = c != null
        ? masterClientLabel(c)
        : (fallbackName ?? '');
  }

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
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Iconsax.briefcase,
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
                  "Create Project",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Set up a new project and assign a team",
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

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Color? accentColor,
  }) {
    final Color badgeColor = accentColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: badgeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.grey200, thickness: 1),
            const SizedBox(height: 16),
            child,
          ],
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
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Scrollbar(
                      controller: _vScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                        controller: _vScrollController,
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: _buildSectionCard(
                            icon: Iconsax.briefcase,
                            title: "Project Details",
                            subtitle:
                                "Give this project a name, owner and timeline",
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  _buildFormFields(constraints),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(
          label: "Create",
          icon: Iconsax.add,
          onSubmit: _submitForm,
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required String label,
    required IconData icon,
    required VoidCallback onSubmit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
        children: [
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Cancel",
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Container(
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
                  onTap: onSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
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
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(BoxConstraints constraints) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;
    const int gridCounts = 2;
    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            key: ValueKey('project_name_${_dealList.length}'),
            label: 'Project Name',
            isRequired: true,
            items: _dealOptions.keys.toList(),
            validator: (input) => input == null || input.toString().isEmpty
                ? 'Project Name is required'
                : null,
            onChanged: _onProjectSelected,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Project Description',
            controller: _projectDescriptionController,
            hintText: 'Enter Project Description',
            maxLines: 2,
            keyboardType: TextInputType.multiline,
            prefixIcon: const Icon(Iconsax.document_text, size: 18),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            label: 'Project Lead',
            isRequired: true,
            validator: (input) => input == null || input.isEmpty
                ? 'Project Lead is required'
                : null,
            items: _employeesList.map((e) => e.name).toList(),
            onChanged: (value) async {
              var employeeModel = _employeesList.firstWhere(
                (element) => element.name == value,
              );
              _selectedProjectOwner = employeeModel.uid;
              setState(() {});
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            label: 'Team Lead',
            isRequired: true,
            validator: (input) =>
                input == null || input.isEmpty ? 'Team Lead is required' : null,
            items: _employeesList.map((e) => e.name).toList(),
            onChanged: (value) async {
              var employeeModel = _employeesList.firstWhere(
                (element) => element.name == value,
              );
              _selectedTeamLead = employeeModel.uid;
              setState(() {});
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Members',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomSearchableDropdown(
                items: _employeesList.map((e) => e.name).toList(),
                multiSelect: true,
                onChangedList: (list) {
                  for (var i in list) {
                    final emp = _employeesList.firstWhere(
                      (element) => element.name == i,
                    );
                    if (emp.uid != null &&
                        !_selectedProjectMembers.contains(emp.uid)) {
                      _selectedProjectMembers.add(emp.uid!);
                    }
                  }
                },
                itemAsString: (s) => s,
              ),
            ],
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            key: ValueKey('master_client_${_masterClientController.text}'),
            label: 'Master Client',
            controller: _masterClientController,
            hintText: 'Auto-selected from Project Name',
            readOnly: true,
            prefixIcon: const Icon(Iconsax.building, size: 18),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Project Code',
            controller: _projectCodeController,
            hintText: 'Enter Project Code',
            prefixIcon: const Icon(Iconsax.code, size: 18),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Category',
            controller: _categoryController,
            hintText: 'Enter Category',
            prefixIcon: const Icon(Iconsax.category, size: 18),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Start Date',
            controller: _startDateController,
            hintText: 'Select date & time',
            readOnly: true,
            suffixIcon: const Icon(Iconsax.calendar_edit),
            onTap: () async {
              var selectedDate = await datePicker(context);
              if (selectedDate != null) {
                if (!mounted) return;
                var selectedTime = await pickTime(context, null);
                if (selectedTime != null) {
                  var combined = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  _startDateController.text = combined.formatDateTime;
                  _selectedStartDate = combined;
                  setState(() {});
                }
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'End Date',
            controller: _endDateController,
            hintText: 'Select date & time',
            readOnly: true,
            suffixIcon: const Icon(Iconsax.calendar_edit),
            onTap: () async {
              var selectedDate = await datePicker(context);
              if (selectedDate != null) {
                if (!mounted) return;
                var selectedTime = await pickTime(context, null);
                if (selectedTime != null) {
                  var combined = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  _endDateController.text = combined.formatDateTime;
                  _selectedEndDate = combined;
                  setState(() {});
                }
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Deadline',
            controller: _deadlineController,
            hintText: 'Select date & time',
            readOnly: true,
            suffixIcon: const Icon(Iconsax.notification),
            onTap: () async {
              var selectedDate = await datePicker(context);
              if (selectedDate != null) {
                if (!mounted) return;
                var selectedTime = await pickTime(context, null);
                if (selectedTime != null) {
                  var combined = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  _deadlineController.text = combined.formatDateTime;
                  _selectedDeadlineDate = combined;
                  setState(() {});
                }
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Tags',
            controller: _tagsController,
            hintText: 'Eg. UI, API, Urgent',
            maxLines: 2,
            prefixIcon: const Icon(Iconsax.tag, size: 18),
          ),
        ),
      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        var projectCodeExists = _projectCodeController.text.trim().isNotEmpty
            ? await ProjectService.checkProjectCodeExists(
                code: _projectCodeController.text.trim(),
              )
            : false;

        if (projectCodeExists) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(
            context,
            'Project Code already exists',
            isSuccess: false,
          );
          return;
        }

        final nameTaken = _otherProjects.any(
          (p) =>
              _normName(p.projectName) ==
              _normName(_projectNameController.text),
        );
        if (nameTaken) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(
            context,
            'A project with this name already exists',
            isSuccess: false,
          );
          return;
        }

        ProjectModel projectModel = ProjectModel(
          projectName: _projectNameController.text.trim(),
          projectDescription: _projectDescriptionController.text.trim(),
          projectOwner: _selectedProjectOwner ?? '',
          teamLead: _selectedTeamLead ?? '',
          members: _selectedProjectMembers,
          clientId: _selectedMasterClient,
          dealId: _selectedDealId,
          projectCode: _projectCodeController.text.trim(),
          category: _categoryController.text.trim(),
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
          deadline: _selectedDeadlineDate,
          tags: _tagsController.text.trim(),
          createdBy: await Spdb.getUser(),
        );

        await ProjectService.createProject(project: projectModel);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(context, 'Project created successfully', isSuccess: true);
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        debugPrint("${e.toString()}, ${st.toString()}");
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(
          context,
          e.toString(),
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}