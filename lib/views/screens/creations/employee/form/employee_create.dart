import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import '/theme/theme.dart';

class EmployeeCreate extends StatefulWidget {
  const EmployeeCreate({super.key});

  @override
  State<EmployeeCreate> createState() => _EmployeeCreateState();
}

class _EmployeeCreateState extends State<EmployeeCreate> {
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _dateOfJoiningController =
      TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  DateTime? _selectedDateOfJoining;
  DateTime? _selectedDateOfBirth;

  bool _passwordVisible = false;
  XFile? _selectedProfileImage;
  Uint8List? _selectedProfileImageBytes;

  List<RoleModel> _rolesList = [];
  List<DesignationModel> _designationList = [];
  List<DepartmentModel> _departmentList = [];
  final List<String> _department = [];
  final List<SubDepartmentModel> _subDepartmentList = [];
  final List<String> _reportingTo = [];
  List<dynamic> _reportingToObjects = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late Future _future;
  int _currentStep = 0;

  String? _gender;
  String _loginAllowed = 'Yes';
  String _receiveEmailNotifications = 'Yes';
  String _maritalStatus = 'Single';
  String? _employeeType;
  final String _outsideOffice = 'No';

  RoleModel? _roleModel;
  DesignationModel? _designationModel;
  // DepartmentModel? _departmentModel;
  SubDepartmentModel? _subDepartmentModel;
  EmployeeModel? employee;
  bool _isActive = true;

  // State preservation for employee fields when toggling Make as Admin
  String? _preservedEmployeeId;
  String? _preservedDesignation;
  List<String> _preservedDepartment = [];
  String? _preservedSubDepartment;
  String? _preservedGender;
  String? _preservedDateOfJoining;
  String? _preservedRole;
  List<String> _preservedReportingTo = [];
  List<dynamic> _preservedReportingToObjects = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = _init();

    if (employee != null) {
      _isActive = employee!.isActive;
    }
  }

  

  Future<void> _init() async {
    try {
      _rolesList.clear();
      _designationList.clear();
      _departmentList.clear();
      _subDepartmentList.clear();

      _rolesList = await RoleService.getAllRoles();
      _designationList = await DesignationService.getAllDesignations();
      _departmentList = await DepartmentService.getAllDepartments();

      final generatedId = await EmployeeService.generateEmployeeId();
      _employeeIdController.text = generatedId;

      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileNumberController.dispose();
    _dateOfJoiningController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Gallery-only image picker that works on web, mobile and Windows.
  /// Uses XFile + bytes throughout (no dart:io File) so it never breaks on
  /// web, where XFile paths are blob: URLs rather than real file paths.
  Future<void> pickImage() async {
    try {
      XFile? imageFile;

      if (kIsWindows) {
        // Windows: image_picker has no gallery implementation, use file_picker.
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          dialogTitle: 'Select a profile photo',
        );
        if (result == null || result.files.isEmpty) return;
        final pickedPath = result.files.single.path;
        if (pickedPath == null) return;
        imageFile = XFile(pickedPath);
      } else if (kIsWeb) {
        // Web: use file_picker with bytes instead of
        // ImagePicker().pickImage(imageQuality: ...). Passing imageQuality
        // makes image_picker_for_web resize the image on a <canvas> and hand
        // back an XFile backed by a blob: object URL; the later
        // imageFile.readAsBytes() fetch of that blob URL can fail once the
        // browser revokes it (reliably reproducible in InPrivate/Incognito),
        // throwing "Could not load Blob from its URL. Has it been revoked?".
        // file_picker's withData: true returns the raw bytes directly, with
        // no intermediate blob URL to revoke.
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
          dialogTitle: 'Select a profile photo',
        );
        if (result == null || result.files.isEmpty) return;
        final pf = result.files.single;
        if (pf.bytes == null) return;
        imageFile = XFile.fromData(pf.bytes!, name: pf.name);
      } else {
        // Mobile/native desktop: gallery only, with EXIF rotation.
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 512,
        );
        if (picked == null) return;
        final rotated = await FlutterExifRotation.rotateImage(
          path: picked.path,
        );
        imageFile = XFile(rotated.path);
      }

      final bytes = await imageFile.readAsBytes();

      if (mounted) {
        setState(() {
          _selectedProfileImage = imageFile;
          _selectedProfileImageBytes = bytes;
        });
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        FlushBar.show(context, 'Failed to pick image: $e', isSuccess: false);
      }
    }
  }

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  Widget _buildHeader(BuildContext context) {
    const List<String> stepSubtitles = [
      "Add a profile photo and the employee's personal information",
      "Assign designation, department and reporting structure",
      "Add contact details and other employment preferences",
    ];

    final int subtitleIndex = _currentStep.clamp(0, stepSubtitles.length - 1);

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
              Iconsax.user_add,
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
                  "Create Employee",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stepSubtitles[subtitleIndex],
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

  Widget _buildStepper() {
    final steps = [
      {'label': 'Personal', 'icon': Iconsax.user},
      {'label': 'Work', 'icon': Iconsax.briefcase},
      {'label': 'Extra Info', 'icon': Iconsax.info_circle},
    ];
    final primaryColor = Theme.of(context).colorScheme.primary;
    final outlineColor = Theme.of(context).colorScheme.outlineVariant;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length * 2 - 1, (i) {
          // Odd indices = connector lines
          if (i.isOdd) {
            final stepIndex = i ~/ 2;
            final isLineActive = stepIndex < _currentStep;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 19, bottom: 24),
                color: isLineActive ? primaryColor : outlineColor,
              ),
            );
          }

          final index = i ~/ 2;
          final isCompleted = index < _currentStep;
          final isActive = index == _currentStep;
          final stepIcon = steps[index]['icon'] as IconData;
          final stepLabel = steps[index]['label'] as String;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isCompleted || isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                        )
                      : null,
                  border: Border.all(
                    color: isCompleted || isActive
                        ? primaryColor
                        : outlineColor,
                    width: 2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : Icon(
                          stepIcon,
                          size: 17,
                          color: isActive ? Colors.white : onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stepLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isCompleted || isActive
                      ? primaryColor
                      : onSurfaceVariant,
                ),
              ),
            ],
          );
        }),
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right:8.0),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Form(
                          key: _formKey,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Column(
                              children: [
                                _buildStepper(),
                                const SizedBox(height: 20),
                                if (_currentStep == 0) ...[
                                  _buildSectionCard(
                                    icon: Iconsax.gallery,
                                    accentColor: Theme.of(context).colorScheme.primary,
                                    title: "Profile Photo",
                                    subtitle:
                                        "Add a profile picture to personalize this account",
                                    child: Center(child: _buildProfileUploader()),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSectionCard(
                                    icon: Iconsax.user,
                                    accentColor: AppColors.secondary,
                                    title: "Personal Details",
                                    subtitle:
                                        "Basic information used to identify the employee",
                                    child: LayoutBuilder(
                                      builder: (context, constraints) =>
                                          _buildPersonalFormFields(constraints, 4),
                                    ),
                                  ),
                                ] else if (_currentStep == 1) ...[
                                  _buildSectionCard(
                                    icon: Iconsax.briefcase,
                                    accentColor: AppColors.orange,
                                    title: "Work Details",
                                    subtitle:
                                        "Role, department and reporting structure",
                                    child: LayoutBuilder(
                                      builder: (context, constraints) =>
                                          _buildWorkFormFields(constraints, 4),
                                    ),
                                  ),
                                ] else if (_currentStep == 2) ...[
                                  _buildSectionCard(
                                    icon: Iconsax.call,
                                    accentColor: AppColors.success,
                                    title: "Contact Information",
                                    subtitle:
                                        "Address and a short note about the employee",
                                    child: LayoutBuilder(
                                      builder: (context, constraints) =>
                                          _buildContactFormFields(constraints, 2),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSectionCard(
                                    icon: Iconsax.setting_2,
                                    accentColor: AppColors.primary,
                                    title: "Other Details",
                                    subtitle:
                                        "Login access, notifications and employment type",
                                    child: LayoutBuilder(
                                      builder: (context, constraints) =>
                                          _buildOthersFormFields(constraints, 4),
                                    ),
                                  ),
                                ],
                              ],
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
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
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
          if (_currentStep > 0) ...[
            Expanded(
              child: _buildSecondaryButton(
                label: "Back",
                icon: Iconsax.arrow_left_2,
                onTap: () {
                  setState(() {
                    _currentStep--;
                  });
                },
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: _currentStep < 2
                ? _buildPrimaryButton(
                    label: "Next",
                    icon: Iconsax.arrow_right_3,
                    iconTrailing: true,
                    onTap: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          _currentStep++;
                        });
                      }
                    },
                  )
                : _buildPrimaryButton(
                    label: "Create Employee",
                    icon: Iconsax.tick_circle,
                    iconTrailing: false,
                    onTap: _submitForm,
                  ),
          ),
        ],
      ),
    );
  }

  /// Neutral, filled "Back" action - visually secondary to the primary
  /// gradient action, but still solid and easy to tap (not a thin outline).
  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Primary "Next" / "Create Employee" action - a gradient pill that
  /// echoes the header banner, with a soft glow so it reads as the one
  /// obvious next action on the screen.
  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool iconTrailing = true,
  }) {
    return Container(
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: iconTrailing
                  ? [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, size: 18, color: Colors.white),
                    ]
                  : [
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

  Widget _buildProfileUploader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: pickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _brandGradient,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.surface,
                      image: _selectedProfileImageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_selectedProfileImageBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedProfileImage == null
                        ? Icon(
                            Iconsax.user,
                            size: 44,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.6),
                          )
                        : null,
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.secondary,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    kIsWindows ? Iconsax.document_upload : Iconsax.camera,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: pickImage,
            child: Text(
              kIsWindows
                  ? (_selectedProfileImage != null
                        ? 'Tap to change photo'
                        : 'Choose Image File')
                  : (_selectedProfileImage != null
                        ? 'Tap to change photo'
                        : 'Tap to add photo'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'JPG or PNG, up to 5MB (optional)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;
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
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Employee Id',
              controller: _employeeIdController,
              hintText: 'Enter Employee Id',
              isRequired: true,
              prefixIcon: const Icon(Iconsax.personalcard, size: 18),
              valid: (input) => Validation.commonValidation(
                input: input,
                label: 'Employee Id',
                isReq: true,
              ),
            ),
          ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Employee Name',
            controller: _nameController,
            hintText: 'Enter Employee Name',
            isRequired: true,
            prefixIcon: const Icon(Iconsax.user, size: 18),
            valid: (input) => Validation.validName(
              input: input,
              label: 'Employee Name',
              isReq: true,
            ),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Email',
            controller: _emailController,
            hintText: 'Enter Email',
            isRequired: true,
            prefixIcon: const Icon(Iconsax.sms, size: 18),
            valid: (input) => Validation.validEmail(input: input, isReq: true),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Password',
            controller: _passwordController,
            hintText: 'Enter Password',
            isRequired: true,
            prefixIcon: const Icon(Iconsax.lock, size: 18),
            valid: (input) =>
                Validation.passwordValidation(input: input, isReq: true),
            obsecureText: !_passwordVisible,
            suffixIcon: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              splashRadius: 1,
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              icon: Icon(
                _passwordVisible ? Iconsax.eye : Iconsax.eye_slash,
                size: 20,
              ),
            ),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Mobile Number',
            controller: _mobileNumberController,
            hintText: 'Enter Mobile Number',
            prefixIcon: const Icon(Iconsax.mobile, size: 18),
            valid: (input) =>
                Validation.validMobileNumber(input: input, isReq: false),
          ),
        ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormDropdownSearch(
              initialItem: _gender,
              items: const ['Male', 'Female', 'Others'],
              label: 'Gender',
              isRequired: true,
              onChanged: (value) {
                if (value != null) {
                  _gender = value.toString();
                }
              },
              validator: (value) {
                if (value == null) {
                  return "* Required";
                }
                return null;
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Birth Date',
              controller: _dateOfBirthController,
              hintText: 'DD/MM/YYYY',
              readOnly: true,
              prefixIcon: const Icon(Iconsax.cake, size: 18),
              onTap: () async {
                var result = await datePicker(context, lastDate: DateTime.now());
                if (result != null) {
                  _dateOfBirthController.text = result.formatDate;
                  _selectedDateOfBirth = result;
                }
              },
            ),
          ),
      ],
    );
  }

  bool isAdmin = false;

  void _handleIsAdminChange(bool value) {
    if (value == isAdmin) return;

    if (value) {
      // Switching to admin mode - preserve employee field values
      _preservedEmployeeId = _employeeIdController.text;
      _preservedDesignation = _designationModel?.uid;
      _preservedDepartment = List.from(_department);
      _preservedSubDepartment = _subDepartmentModel?.uid;
      _preservedGender = _gender;
      _preservedDateOfJoining = _dateOfJoiningController.text;
      _preservedRole = _roleModel?.uid;
      _preservedReportingTo = List.from(_reportingTo);
      _preservedReportingToObjects = List.from(_reportingToObjects);
    } else {
      // Switching to employee mode - restore preserved values
      _employeeIdController.text = _preservedEmployeeId ?? '';
      _dateOfJoiningController.text = _preservedDateOfJoining ?? '';
      _gender = _preservedGender;
      _department.clear();
      _department.addAll(_preservedDepartment);
      _reportingTo.clear();
      _reportingTo.addAll(_preservedReportingTo);
      _reportingToObjects.clear();
      _reportingToObjects.addAll(_preservedReportingToObjects);

      // Restore dropdown models asynchronously
      if (_preservedDesignation != null) {
        _designationModel = _designationList.firstWhere(
          (d) => d.uid == _preservedDesignation,
          orElse: () => _designationList.first,
        );
      }
      if (_preservedSubDepartment != null) {
        try {
          _subDepartmentModel = _subDepartmentList.firstWhere(
            (sd) => sd.uid == _preservedSubDepartment,
          );
        } catch (e) {
          _subDepartmentModel = _subDepartmentList.isNotEmpty
              ? _subDepartmentList.first
              : null;
        }
      }
      if (_preservedRole != null) {
        _roleModel = _rolesList.firstWhere(
          (r) => r.uid == _preservedRole,
          orElse: () => _rolesList.first,
        );
      }
    }

    setState(() {
      isAdmin = value;
    });
  }

  Widget _buildWorkFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;
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
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: CustomFutureSearchableDropdown<DesignationModel>(
              label: 'Designation',
              isRequired: true,
              initialValue: _designationModel,
              validator: (value) {
                if (_designationModel == null) {
                  return 'Designation is required';
                }
                return null;
              },
              asyncItems: () async {
                var designations =
                    await DesignationService.getAllDesignations();
                return designations;
              },
              itemAsString: (desigantion) => desigantion.name,
              onChanged: (selectedDes) async {
                if (selectedDes != null) {
                  _designationModel = selectedDes;
                }
                setState(() {});
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: CustomFutureSearchableDropdown<DepartmentModel>(
              label: 'Department',
              isRequired: true,
              initialValues: _departmentList
                  .where((d) => _department.contains(d.uid))
                  .toList(),
              validator: (value) {
                if (_department.isEmpty) {
                  return 'Department is required';
                }
                return null;
              },
              asyncItems: () async {
                var departments = await DepartmentService.getAllDepartments();
                return departments;
              },
              multiSelect: true,
              itemAsString: (department) => department.name,
              onChangedList: (selectedDeps) async {
                _department.clear();
                for (var d in selectedDeps) {
                  _department.add(d.uid ?? '');
                }

                setState(() {});
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: CustomFutureSearchableDropdown<SubDepartmentModel>(
              label: 'Sub Department',
              initialValue: _subDepartmentModel,
              asyncItems: () async {
                List<SubDepartmentModel> subDepartmentList = [];
                for (var depId in _department) {
                  final list =
                      await SubDepartmentService.getSubDepartmentsByDepId(
                        depId: depId,
                      );
                  subDepartmentList.addAll(list);
                }

                return subDepartmentList;
              },
              itemAsString: (subDepartment) => subDepartment.name,
              onChanged: (subDepartment) async {
                if (subDepartment != null) {
                  _subDepartmentModel = subDepartment;
                }

                setState(() {});
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Joining Date',
              controller: _dateOfJoiningController,
              hintText: 'DD/MM/YYYY',
              readOnly: true,
              isRequired: true,
              prefixIcon: const Icon(Iconsax.calendar_tick, size: 18),
              valid: (input) => Validation.commonValidation(
                input: input,
                label: 'Joining Date',
                isReq: true,
              ),
              onTap: () async {
                var result = await datePicker(context);
                if (result != null) {
                  _dateOfJoiningController.text = result.formatDate;
                  _selectedDateOfJoining = result;
                }
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: CustomFutureSearchableDropdown<RoleModel>(
              label: 'Role',
              isRequired: true,
              initialValue: _roleModel,
              validator: (value) {
                if (_roleModel == null) {
                  return 'Role is required';
                }
                return null;
              },
              asyncItems: () async {
                var roles = await RoleService.getAllRoles();
                return roles;
              },
              itemAsString: (role) => role.name,
              onChanged: (selectedRole) async {
                if (selectedRole != null) {
                  _roleModel = selectedRole;
                }
                setState(() {});
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: UsersListDropdown(
              label: 'Reporting To',
              initialValues: _reportingToObjects,
              onChangedList: (list) {
                _reportingToObjects = list;
                _reportingTo.clear();
                _reportingTo.addAll(list.map((e) => e.uid!));
              },
              includeCurrentUser: false,
            ),
          ),
        Container(
          width: itemWidth,
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Iconsax.shield_tick,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Make as Admin",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Checkbox(
                value: isAdmin,
                onChanged: (value) {
                  _handleIsAdminChange(value ?? false);
                },
              ),
            ],
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isActive ? Iconsax.tick_circle : Iconsax.close_circle,
                      size: 18,
                      color: _isActive
                          ? AppColors.success
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isActive ? 'Active' : 'Inactive',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _isActive
                            ? AppColors.success
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isActive,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

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
          child: FormFields(
            label: 'Address',
            controller: _addressController,
            hintText: 'Enter Address',
            maxLines: 2,
            prefixIcon: const Icon(Iconsax.location, size: 18),
            valid: (input) =>
                Validation.validAddress(input: input ?? '', isReq: false),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'About',
            controller: _aboutController,
            hintText: 'Enter About',
            maxLines: 2,
            prefixIcon: const Icon(Iconsax.document_text, size: 18),
            valid: (input) => Validation.commonValidation(
              input: input,
              label: 'About',
              isReq: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOthersFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

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
            items: const ['Yes', 'No'],
            initialItem: 'Yes',
            label: 'Login Allowed',
            onChanged: (value) {
              if (value != null) {
                _loginAllowed = value.toString();
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            items: const ['Yes', 'No'],
            initialItem: 'Yes',
            label: 'Receive Email Notifications',
            onChanged: (value) {
              if (value != null) {
                _receiveEmailNotifications = value.toString();
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            items: const ['Single', 'Married'],
            initialItem: 'Single',
            label: 'Marital Status',
            onChanged: (value) {
              if (value != null) {
                _maritalStatus = value.toString();
              }
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormDropdownSearch(
            items: const [
              'Full Time',
              'Part Time',
              'On Contract',
              'Internship',
              'Trainee',
            ],
            label: 'Employee Type',
            onChanged: (value) {
              if (value != null) {
                _employeeType = value.toString();
              }
            },
          ),
        ),
        // SizedBox(
        //   width: itemWidth,
        //   child: FormDropdownSearch(
        //     items: const ['Yes', 'No'],
        //     initialItem: 'No',
        //     label: 'Allow Outside Office Punch',
        //     onChanged: (value) {
        //       if (value != null) {
        //         _outsideOffice = value.toString();
        //       }
        //     },
        //   ),
        // ),
      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (isAdmin) {
          futureLoading(context);

          var duplicateError = await EmployeeService.checkContactExists(
            email: _emailController.text.trim(),
            mobileNumber: _mobileNumberController.text.trim(),
          );

          if (duplicateError != null) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            FlushBar.show(context, duplicateError, isSuccess: false);
            return;
          }

          String? profileImageUrl;
          if (_selectedProfileImage != null) {
            profileImageUrl = await xFileToUploadUrl(
              _selectedProfileImage!,
              StorageFolder.userPhotos,
            );
          }

          AdminModel admin = AdminModel(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            mobileNumber: _mobileNumberController.text.trim(),
            profileImageUrl: profileImageUrl,
            createdBy: await Spdb.getUser(),
          );

          await AdminService.createAdmin(admin: admin);
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          Navigator.pop(context, true);

          FlushBar.show(
            context,
            'Employee created successfully',
            isSuccess: true,
          );
        } else {
          futureLoading(context);

          var duplicateError = await EmployeeService.checkEmployeeExists(
            employeeId: _employeeIdController.text,
            email: _emailController.text.trim(),
            mobileNumber: _mobileNumberController.text.trim(),
          );

          if (duplicateError != null) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            FlushBar.show(context, duplicateError, isSuccess: false);
            return;
          }

          String? profileImageUrl;
          if (_selectedProfileImage != null) {
            profileImageUrl = await xFileToUploadUrl(
              _selectedProfileImage!,
              StorageFolder.userPhotos,
            );
          }

          EmployeeModel employee = EmployeeModel(
            employeeId: _employeeIdController.text,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            designation: _designationModel?.uid ?? '',
            department: _department,
            subDepartment: _subDepartmentModel?.uid,
            mobileNumber: _mobileNumberController.text.trim(),
            gender: _gender ?? 'Male',
            dateOfJoining: _selectedDateOfJoining!,
            dateOfBirth: _selectedDateOfBirth,
            role: _roleModel?.uid ?? '',
            address: _addressController.text.trim(),
            about: _aboutController.text.trim(),
            loginAllowed: _loginAllowed == 'Yes',
            receiveEmailNotifications: _receiveEmailNotifications == 'Yes',
            maritalStatus: _maritalStatus,
            isActive: _isActive,
            employeeType: _employeeType ?? '',
            profileImageUrl: profileImageUrl,
            skills: '',
            reportingTo: _reportingTo,
            outsideOffice: _outsideOffice == 'Yes',
            createdBy: await Spdb.getUser(),
          );

          await EmployeeService.createEmployee(employee: employee);
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          Navigator.pop(context, true);

          FlushBar.show(
            context,
            'Employee created successfully',
            isSuccess: true,
          );
        }
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