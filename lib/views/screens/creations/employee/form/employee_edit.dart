import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';

class EmployeeEdit extends StatefulWidget {
  final String uid;
  final AdminModel? admin;
  const EmployeeEdit({super.key, required this.uid, this.admin});

  @override
  State<EmployeeEdit> createState() => _EmployeeEditState();
}

class _EmployeeEditState extends State<EmployeeEdit> {
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _dateOfJoiningController =
      TextEditingController();
  DateTime? _selectedDateOfJoining;
  final TextEditingController _dateOfBirthController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  bool _passwordVisible = false;

  List<RoleModel> _rolesList = [];
  List<DesignationModel> _designationList = [];
  List<DepartmentModel> _departmentList = [];
  List<SubDepartmentModel> _subDepartmentList = [];
  final List<dynamic> _initialReportingTo = [];

  final List<String> _reportingTo = [];
  final List<String> _department = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late Future _future;

  String? _gender;
  String _loginAllowed = 'Yes';
  String _receiveEmailNotifications = 'Yes';
  String _maritalStatus = 'Single';
  String? _employeeType;
  String _outsideOffice = 'No';

  XFile? _selectedProfileImage;
  Uint8List? _selectedProfileImageBytes;
  String? _profileImageUrl;
  bool _oldProfileImageRemoved = false;

  RoleModel? _roleModel;
  DesignationModel? _designationModel;
  DepartmentModel? _departmentModel;
  SubDepartmentModel? _subDepartmentModel;
  EmployeeModel? employee;
  EmployeeModel? _originalEmployee;
  AdminModel? _originalAdmin;
  bool _isActive = true;

  // State preservation for current form values when toggling Make as Admin
  String? _preservedEmployeeId;
  String? _preservedDesignation;
  List<String> _preservedDepartment = [];
  String? _preservedSubDepartment;
  String? _preservedGender;
  String? _preservedDateOfJoining;
  String? _preservedRole;
  List<String> _preservedReportingTo = [];
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
      _initialReportingTo.clear();

      if (widget.admin != null) {
        _originalAdmin = widget.admin;
        _employeeIdController.text = "";
        _nameController.text = widget.admin!.name;
        _emailController.text = widget.admin!.email;
        _passwordController.text = widget.admin!.password;
        _mobileNumberController.text = widget.admin!.mobileNumber;
        _selectedDateOfBirth = widget.admin!.createdAt;
        _profileImageUrl = widget.admin!.profileImageUrl;
        isAdmin = true;

        // Pull the fields that live directly on the admin record now.
        _addressController.text = widget.admin!.address ?? '';
        _aboutController.text = widget.admin!.about ?? '';
        _skillsController.text = widget.admin!.skills ?? '';
        _employeeType = widget.admin!.employeeType;
        _maritalStatus = widget.admin!.maritalStatus ?? 'Single';
        _loginAllowed = (widget.admin!.loginAllowed ?? true) ? 'Yes' : 'No';
        _receiveEmailNotifications =
            (widget.admin!.receiveEmailNotifications ?? true) ? 'Yes' : 'No';
        _outsideOffice = (widget.admin!.outsideOffice ?? false)
            ? 'Yes'
            : 'No';

        // Backward compatibility: older records converted to Admin before
        // this fix don't have these fields on the admin document yet. For
        // those, fall back to whatever was captured in the trash entry
        // when the employee document was deleted.
        try {
          final cid = await Spdb.getCid();
          final snap = await FirebaseFirestore.instance
              .collection(Collections.users.name)
              .doc(cid)
              .collection(Collections.trash.name)
              .where('documentId', isEqualTo: widget.uid)
              .where('collection', isEqualTo: 'employees')
              .limit(1)
              .get();

          if (snap.docs.isNotEmpty) {
            final trashData = snap.docs.first.data();
            final employeeData = trashData['data'] as Map<String, dynamic>?;
            if (employeeData != null) {
              employee = EmployeeModel.fromMap(widget.uid, employeeData);
              _originalEmployee = employee;

              _preservedEmployeeId = employee!.employeeId;
              _preservedDesignation = employee!.designation;
              _preservedDepartment = List.from(employee!.department ?? []);
              _preservedSubDepartment = employee!.subDepartment;
              _preservedGender = employee!.gender;
              _preservedDateOfJoining = employee!.dateOfJoining.formatDate;
              _preservedRole = employee!.role;
              _preservedReportingTo = List.from(employee!.reportingTo ?? []);

              // Only use the trashed values as a fallback when the admin
              // document itself doesn't already have them.
              if (widget.admin!.skills == null) {
                _skillsController.text = employee!.skills;
              }
              if (widget.admin!.address == null) {
                _addressController.text = employee!.address;
              }
              if (widget.admin!.about == null) {
                _aboutController.text = employee!.about;
              }
              if (widget.admin!.loginAllowed == null) {
                _loginAllowed = employee!.loginAllowed ? 'Yes' : 'No';
              }
              if (widget.admin!.receiveEmailNotifications == null) {
                _receiveEmailNotifications =
                    employee!.receiveEmailNotifications ? 'Yes' : 'No';
              }
              if (widget.admin!.maritalStatus == null) {
                _maritalStatus = employee!.maritalStatus;
              }
              if (widget.admin!.employeeType == null) {
                _employeeType = employee!.employeeType;
              }
              if (widget.admin!.outsideOffice == null) {
                _outsideOffice = employee!.outsideOffice ? 'Yes' : 'No';
              }
            }
          }
        } catch (e) {
          debugPrint("Failed to fetch employee from trash: $e");
        }
      } else {
        _rolesList = await RoleService.getAllRoles();
        _designationList = await DesignationService.getAllDesignations();
        _departmentList = await DepartmentService.getAllDepartments();

        employee = await EmployeeService.getEmployee(uid: widget.uid);
        _originalEmployee = employee;
        _employeeIdController.text = employee!.employeeId;
        _nameController.text = employee!.name;
        _emailController.text = employee!.email;
        _passwordController.text = employee!.password;
        _mobileNumberController.text = employee!.mobileNumber;
        _dateOfJoiningController.text = employee!.dateOfJoining.formatDate;
        _selectedDateOfJoining = employee!.dateOfJoining;
        _dateOfBirthController.text = employee!.dateOfBirth?.formatDate ?? '';
        _selectedDateOfBirth = employee!.dateOfBirth;
        _addressController.text = employee!.address;
        _aboutController.text = employee!.about;
        _skillsController.text = employee!.skills;

        _gender = employee!.gender;
        _loginAllowed = employee!.loginAllowed ? 'Yes' : 'No';
        _receiveEmailNotifications = employee!.receiveEmailNotifications
            ? 'Yes'
            : 'No';
        _maritalStatus = employee!.maritalStatus;
        _isActive = employee!.isActive;
        _employeeType = employee!.employeeType;
        _outsideOffice = employee!.outsideOffice ? 'Yes' : 'No';
        _profileImageUrl = employee!.profileImageUrl;

        _roleModel = await RoleService.getRole(uid: employee!.role);
        _designationModel = await DesignationService.getDesignation(
          uid: employee!.designation,
        );

        if (employee!.department != null && employee!.department!.isNotEmpty) {
          _department.clear();
          _department.addAll(employee!.department!);
        }

        if (_departmentModel != null) {
          _subDepartmentList =
              await SubDepartmentService.getSubDepartmentsByDepId(
                depId: _departmentModel!.uid ?? '',
              );
        }

        if (employee!.subDepartment != null &&
            employee!.subDepartment!.isNotEmpty) {
          _subDepartmentModel = await SubDepartmentService.getSubDepartment(
            uid: employee!.subDepartment ?? '',
          );
        }

        for (var i in (employee?.reportingTo ?? [])) {
          var emp = await EmployeeService.getEmployee(uid: i);
          if (emp != null) {
            _initialReportingTo.add(emp);
          } else {
            var admin = await AdminService.getAdmin(uid: i);
            if (admin != null) {
              _initialReportingTo.add(admin);
            }
          }
        }
      }

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

  Future<void> _handleIsAdminChange(bool value) async {
    if (value == isAdmin) return;

    if (value) {
      // Switching to admin mode - preserve current employee field values
      _preservedEmployeeId = _employeeIdController.text;
      _preservedDesignation = _designationModel?.uid;
      _preservedDepartment = List.from(_department);
      _preservedSubDepartment = _subDepartmentModel?.uid;
      _preservedGender = _gender;
      _preservedDateOfJoining = _dateOfJoiningController.text;
      _preservedRole = _roleModel?.uid;
      _preservedReportingTo = List.from(_reportingTo);

      // Clear employee-specific fields for admin view
      _employeeIdController.text = "";
      _dateOfJoiningController.text = "";
      _gender = null;
      _department.clear();
      _reportingTo.clear();
      _designationModel = null;
      _subDepartmentModel = null;
      _roleModel = null;
    } else {
      // Switching to employee mode - restore preserved values
      _employeeIdController.text =
          _preservedEmployeeId ?? _originalEmployee?.employeeId ?? '';
      _dateOfJoiningController.text =
          _preservedDateOfJoining ??
          _originalEmployee?.dateOfJoining.formatDate ??
          '';
      _gender = _preservedGender ?? _originalEmployee?.gender;

      _department.clear();
      if (_preservedDepartment.isNotEmpty) {
        _department.addAll(_preservedDepartment);
      } else if (_originalEmployee?.department != null &&
          _originalEmployee!.department!.isNotEmpty) {
        _department.addAll(_originalEmployee!.department!);
      }

      _reportingTo.clear();
      if (_preservedReportingTo.isNotEmpty) {
        _reportingTo.addAll(_preservedReportingTo);
      } else if (_originalEmployee?.reportingTo != null) {
        _reportingTo.addAll(_originalEmployee!.reportingTo!);
      }

      // Ensure dropdown lists are loaded
      if (_rolesList.isEmpty) {
        _rolesList = await RoleService.getAllRoles();
      }
      if (_designationList.isEmpty) {
        _designationList = await DesignationService.getAllDesignations();
      }
      if (_departmentList.isEmpty) {
        _departmentList = await DepartmentService.getAllDepartments();
      }

      // Restore dropdown models
      if (_preservedDesignation != null) {
        _designationModel = _designationList.firstWhere(
          (d) => d.uid == _preservedDesignation,
          orElse: () => _designationList.first,
        );
      } else if (_originalEmployee?.designation != null) {
        _designationModel = await DesignationService.getDesignation(
          uid: _originalEmployee!.designation,
        );
      }

      if (_preservedSubDepartment != null) {
        _subDepartmentList.clear();
        for (var depId in _department) {
          final subDeps = await SubDepartmentService.getSubDepartmentsByDepId(
            depId: depId,
          );
          _subDepartmentList.addAll(subDeps);
        }
        try {
          _subDepartmentModel = _subDepartmentList.firstWhere(
            (sd) => sd.uid == _preservedSubDepartment,
          );
        } catch (e) {
          _subDepartmentModel = _subDepartmentList.isNotEmpty
              ? _subDepartmentList.first
              : null;
        }
      } else if (_originalEmployee?.subDepartment != null) {
        _subDepartmentList.clear();
        for (var depId in _department) {
          final subDeps = await SubDepartmentService.getSubDepartmentsByDepId(
            depId: depId,
          );
          _subDepartmentList.addAll(subDeps);
        }
        _subDepartmentModel = await SubDepartmentService.getSubDepartment(
          uid: _originalEmployee!.subDepartment ?? '',
        );
      }

      if (_preservedRole != null) {
        _roleModel = _rolesList.firstWhere(
          (r) => r.uid == _preservedRole,
          orElse: () => _rolesList.first,
        );
      } else if (_originalEmployee?.role != null) {
        _roleModel = await RoleService.getRole(uid: _originalEmployee!.role);
      }

      // Restore reporting to list
      if (_preservedReportingTo.isNotEmpty) {
        _initialReportingTo.clear();
        for (var uid in _preservedReportingTo) {
          var emp = await EmployeeService.getEmployee(uid: uid);
          if (emp != null) {
            _initialReportingTo.add(emp);
          } else {
            var admin = await AdminService.getAdmin(uid: uid);
            if (admin != null) {
              _initialReportingTo.add(admin);
            }
          }
        }
      }
    }

    setState(() {
      isAdmin = value;
    });
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
    _skillsController.dispose();
_scrollController.dispose();
    super.dispose();
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
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Iconsax.edit, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update Employee",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Update this employee's profile, work and contact details",
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
                    padding: const EdgeInsets.only(right: 8.0),
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
                                _buildSectionCard(
                                  icon: Iconsax.gallery,
                                  accentColor: Theme.of(context).colorScheme.primary,
                                  title: "Profile Photo",
                                  subtitle:
                                      "Add or update the employee's profile picture",
                                  child: Center(child: _buildProfileUploader()),
                                ),
                                const SizedBox(height: 20),
                                _buildSectionCard(
                                  icon: Iconsax.user,
                                  accentColor: AppColors.secondary,
                                  title: "Employee Details",
                                  subtitle:
                                      "Personal information, role and reporting structure",
                                  child: LayoutBuilder(
                                    builder: (context, constraints) =>
                                        _buildFormFields(constraints, 4),
                                  ),
                                ),
                                const SizedBox(height: 20),
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
                                  accentColor: AppColors.orange,
                                  title: "Other Details",
                                  subtitle:
                                      "Login access, notifications and employment type",
                                  child: LayoutBuilder(
                                    builder: (context, constraints) =>
                                        _buildOthersFormFields(constraints, 4),
                                  ),
                                ),
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
          Expanded(
            child: _buildSecondaryButton(
              label: "Cancel",
              icon: Icons.close_rounded,
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: _buildPrimaryButton(
              label: "Update",
              icon: Iconsax.edit,
              onTap: _submitForm,
            ),
          ),
        ],
      ),
    );
  }

  /// Neutral, filled "Cancel" action - visually secondary to the primary
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

  /// Primary "Update" action - a gradient pill that echoes the header
  /// banner, with a soft glow so it reads as the one obvious action.
  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
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
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
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

  void _markProfileImageReplaced() {
    if (_profileImageUrl != null) {
      _profileImageUrl = null;
      _oldProfileImageRemoved = true;
    }
  }

  /// Cross-platform image picker (Android, iOS, Web, Windows).
  ///
  /// Previously this always called FlutterExifRotation.rotateImage() and
  /// stored a dart:io File. FlutterExifRotation has no web implementation,
  /// so on web it threw MissingPluginException("No implementation found for
  /// method rotateImage on channel flutter_exif_rotation"). dart:io File is
  /// also unsupported on web (Image.file() and File.readAsBytes() both fail
  /// there). We now branch by platform and always end up with an XFile +
  /// Uint8List, the same web-safe pattern used in employee_create.dart,
  /// admin_edit.dart and client_edit.dart.
  Future<void> pickImage() async {
    // On Windows: use file picker only (image_picker has no gallery/camera
    // implementation on Windows).
    if (kIsWindows) {
      await _pickImageFromFile();
      return;
    }

    if (kIsWeb) {
      await _pickImageFromFile();
      return;
    }

    // Android / iOS: show the camera vs gallery sheet, then rotate using
    // EXIF data (flutter_exif_rotation only has native Android/iOS support).
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final xFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
      );
      if (xFile == null) return;
      final rotated = await FlutterExifRotation.rotateImage(path: xFile.path);
      final bytes = await rotated.readAsBytes();

      if (mounted) {
        setState(() {
          _selectedProfileImage = XFile(rotated.path);
          _selectedProfileImageBytes = bytes;
          _markProfileImageReplaced();
        });
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        FlushBar.show(context, 'Failed to pick image: $e', isSuccess: false);
      }
    }
  }

  /// Web: file_picker with withData: true returns raw bytes directly, with
  /// no blob: URL and no native plugin involved.
  /// Windows: image_picker has no gallery implementation, so file_picker's
  /// native file dialog is used, then bytes are read from the returned path.
  Future<void> _pickImageFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
        dialogTitle: 'Select a profile photo',
      );

      if (result == null || result.files.isEmpty) return;
      final pf = result.files.single;

      XFile imageFile;
      Uint8List bytes;
      if (kIsWeb) {
        if (pf.bytes == null) return;
        bytes = pf.bytes!;
        imageFile = XFile.fromData(bytes, name: pf.name);
      } else {
        final pickedPath = pf.path;
        if (pickedPath == null) return;
        imageFile = XFile(pickedPath);
        bytes = await imageFile.readAsBytes();
      }

      if (mounted) {
        setState(() {
          _selectedProfileImage = imageFile;
          _selectedProfileImageBytes = bytes;
          _markProfileImageReplaced();
        });
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) {
        FlushBar.show(context, 'Failed to pick image: $e', isSuccess: false);
      }
    }
  }

  Widget _buildProfileUploader() {
    final bool hasImage =
        _selectedProfileImage != null || _profileImageUrl != null;

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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasImage
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _brandGradient,
                          )
                        : null,
                    border: hasImage
                        ? null
                        : Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1.4,
                          ),
                  ),
                  child: ClipOval(
                    child: Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: _selectedProfileImageBytes != null
                          ? Image.memory(
                              // Image.file() is not supported on Flutter
                              // Web, so the preview must always come from
                              // the in-memory bytes rather than the picked
                              // XFile/path.
                              _selectedProfileImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : _profileImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _profileImageUrl!,
                              placeholder: (context, url) =>
                                  Shimmer.fromColors(
                                    baseColor: AppColors.grey300,
                                    highlightColor: AppColors.grey100,
                                    child: Container(color: AppColors.white),
                                  ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Iconsax.user,
                              size: 44,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.6),
                            ),
                    ),
                  ),
                ),
                if (hasImage)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedProfileImage = null;
                        _selectedProfileImageBytes = null;
                        if (_profileImageUrl != null) {
                          _profileImageUrl = null;
                          _oldProfileImageRemoved = true;
                        }
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.error,
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
                        Icons.close_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  )
                else
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
              hasImage
                  ? 'Tap to change photo'
                  : (kIsWindows ? 'Choose Image File' : 'Tap to add photo'),
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

  Widget _buildFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    // Minimum width per column (you can tweak this)
    const double minColumnWidth = 220.0;

    // Calculate the maximum number of columns that can fit
    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    // Calculate each item width
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
              onPressed: () => setState(() {
                _passwordVisible = !_passwordVisible;
              }),
              icon: _passwordVisible
                  ? const Icon(Iconsax.eye)
                  : const Icon(Iconsax.eye_slash),
            ),
          ),
        ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormDropdownSearch(
              initialItem:
                  _designationModel != null &&
                      _designationModel!.name.isNotEmpty
                  ? _designationModel?.name
                  : null,
              items: _designationList.map((e) => e.name.toString()).toList(),
              label: 'Designation',
              isRequired: true,
              onChanged: (value) {
                _designationModel = _designationList.firstWhere(
                  (element) => element.name == value,
                );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Department",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                CustomSearchableDropdown<String>(
                  items: _departmentList.map((e) => e.name.toString()).toList(),
                  multiSelect: true,

                  initialValues: _departmentList
                      .where((d) => _department.contains(d.uid))
                      .map((d) => d.name)
                      .toList(),

                  itemAsString: (s) => s,

                  onChangedList: (selectedNames) async {
                    _department.clear();

                    for (var name in selectedNames) {
                      final dep = _departmentList.firstWhere(
                        (d) => d.name == name,
                      );
                      if (dep.uid != null) {
                        _department.add(dep.uid!);
                      }
                    }

                    _subDepartmentList.clear();

                    for (var depId in _department) {
                      final subDeps =
                          await SubDepartmentService.getSubDepartmentsByDepId(
                            depId: depId,
                          );
                      _subDepartmentList.addAll(subDeps);
                    }

                    setState(() {});
                  },
                ),
              ],
            ),
          ),

        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormDropdownSearch(
              initialItem:
                  _subDepartmentModel != null &&
                      _subDepartmentModel!.name.isNotEmpty
                  ? _subDepartmentModel?.name
                  : null,
              items: _subDepartmentList.map((e) => e.name.toString()).toList(),
              label: 'Sub Department',
              onChanged: (value) {
                _subDepartmentModel = _subDepartmentList.firstWhere(
                  (element) => element.name == value,
                );
              },
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
              initialItem: _gender != null && _gender!.isNotEmpty
                  ? _gender
                  : null,
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
            child: FormFields(
              label: 'Birth Date',
              controller: _dateOfBirthController,
              hintText: 'DD/MM/YYYY',
              readOnly: true,
              prefixIcon: const Icon(Iconsax.cake, size: 18),
              onTap: () async {
                var result = await datePicker(
                  context,
                  lastDate: DateTime.now(),
                );
                if (result != null) {
                  _dateOfBirthController.text = result.formatDate;
                  _selectedDateOfBirth = result;
                }
              },
            ),
          ),
        if (!isAdmin)
          SizedBox(
            width: itemWidth,
            child: FormDropdownSearch(
              initialItem: _roleModel != null && _roleModel!.name.isNotEmpty
                  ? _roleModel?.name
                  : null,
              items: _rolesList.map((e) => e.name.toString()).toList(),
              label: 'Role',
              isRequired: true,
              onChanged: (value) {
                _roleModel = _rolesList.firstWhere(
                  (element) => element.name == value,
                );
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
            child: UsersListDropdown(
              label: 'Reporting To',
              initialValues: _initialReportingTo,
              onChangedList: (list) {
                _reportingTo.clear();
                _reportingTo.addAll(list.map((e) => e.uid!));
                _initialReportingTo.clear();
                _initialReportingTo.addAll(list);
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
                  if (value != null) {
                    _handleIsAdminChange(value);
                  }
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

  bool isAdmin = false;

  Widget _buildContactFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    // Minimum width per column (you can tweak this)
    const double minColumnWidth = 220.0;

    // Calculate the maximum number of columns that can fit
    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    // Calculate each item width
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

    // Minimum width per column (you can tweak this)
    const double minColumnWidth = 220.0;

    // Calculate the maximum number of columns that can fit
    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    // Calculate each item width
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
            initialItem: _loginAllowed,
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
            initialItem: _receiveEmailNotifications,
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
            initialItem: _maritalStatus,
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
            initialItem: _employeeType != null && _employeeType!.isNotEmpty
                ? _employeeType
                : null,
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
        //     initialItem: _outsideOffice,
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
            excludeUid: widget.uid,
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
            // xFileToUploadUrl() works on all platforms: it reads bytes on
            // web (no dart:io File involved) and uploads from the native
            // path on Android/iOS/Windows.
            profileImageUrl = await xFileToUploadUrl(
              _selectedProfileImage!,
              StorageFolder.adminProfile,
            );
          } else if (!_oldProfileImageRemoved) {
            // Keep the existing photo instead of wiping it out just
            // because no new image was picked this time.
            profileImageUrl = _profileImageUrl;
          }

          AdminModel adminModel = AdminModel(
            uid: widget.uid,
            email: _emailController.text.trim(),
            name: _nameController.text.trim(),
            password: _passwordController.text,
            mobileNumber: _mobileNumberController.text.trim(),
            profileImageUrl: profileImageUrl,
            isActive: _isActive,
            createdBy: await Spdb.getUser(),
            // Preserve the fields that stay visible/editable on this form
            // even while "Make as Admin" is on, so they aren't silently
            // discarded (this used to be the cause of Address/About/etc.
            // appearing empty the next time this record was edited).
            address: _addressController.text.trim(),
            about: _aboutController.text.trim(),
            skills: _skillsController.text.trim(),
            employeeType: _employeeType,
            maritalStatus: _maritalStatus,
            loginAllowed: _loginAllowed == 'Yes',
            receiveEmailNotifications: _receiveEmailNotifications == 'Yes',
            outsideOffice: _outsideOffice == 'Yes',
          );

          await AdminService.updateAdmin(id: widget.uid, data: adminModel);

          // Delete the employee document since they're now an admin
          try {
            await EmployeeService.deleteEmployee(uid: widget.uid);
          } catch (e) {
            // If deleting fails, just log it but don't fail the whole process
            debugPrint(
              "Failed to delete employee document after converting to admin: $e",
            );
          }

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          Navigator.pop(context, true);
          FlushBar.show(context, "Admin updated successfully", isSuccess: true);
        } else {
          futureLoading(context);

          var duplicateError = await EmployeeService.checkEmployeeExists(
            employeeId: _employeeIdController.text,
            email: _emailController.text.trim(),
            mobileNumber: _mobileNumberController.text.trim(),
            excludeUid: widget.uid,
          );

          if (duplicateError != null) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            FlushBar.show(context, duplicateError, isSuccess: false);
            return;
          }

          // Determine final profile image URL:
          // - Use newly uploaded image if one was picked
          // - Keep existing URL if the image was not removed
          // - Use null if the image was explicitly removed
          String? profileImageUrl;
          if (_selectedProfileImage != null) {
            profileImageUrl = await xFileToUploadUrl(
              _selectedProfileImage!,
              StorageFolder.userPhotos,
            );
          } else if (!_oldProfileImageRemoved) {
            profileImageUrl = _profileImageUrl;
          }

          if (_oldProfileImageRemoved) {
            await EmployeeService.deleteEmployeeImage(uid: widget.uid);
          }

          EmployeeModel employeeModel = EmployeeModel(
            uid: widget.uid,
            employeeId: _employeeIdController.text,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            designation: _designationModel?.uid ?? '',
            department: _department,
            subDepartment: _subDepartmentModel?.uid,
            mobileNumber: _mobileNumberController.text.trim(),
            gender: _gender ?? 'Male',
            dateOfJoining:
                _selectedDateOfJoining ??
                _originalEmployee?.dateOfJoining ??
                DateTime.now(),
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
            skills: _skillsController.text.trim(),
            reportingTo: _reportingTo,
            outsideOffice: _outsideOffice == 'Yes',
            createdBy: await Spdb.getUser(),
          );

          // Delete the admin document since they're now an employee
          try {
            await AdminService.deleteAdmin(uid: widget.uid);
          } catch (e) {
            debugPrint("Failed to delete admin document: $e");
          }

          final cid = await Spdb.getCid();
          await FirebaseFirestore.instance
              .collection(Collections.users.name)
              .doc(cid)
              .collection(Collections.employees.name)
              .doc(widget.uid)
              .set(employeeModel.toMap());

          // Delete the trash entry for this employee
          try {
            final snap = await FirebaseFirestore.instance
                .collection(Collections.users.name)
                .doc(cid)
                .collection(Collections.trash.name)
                .where('documentId', isEqualTo: widget.uid)
                .where('collection', isEqualTo: 'employees')
                .get();
            for (var doc in snap.docs) {
              await doc.reference.delete();
            }
          } catch (e) {
            debugPrint("Failed to delete trash entry: $e");
          }

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          Navigator.pop(context, true);

          FlushBar.show(
            context,
            'Employee updated successfully',
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