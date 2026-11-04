import 'dart:io' show File;
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import '/theme/theme.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  EmployeeModel? employee;
  AdminModel? admin;
  bool isAdmin = false;
  bool isLoading = true;
  String? editingField;
  XFile? _selectedFile;
  Uint8List? _selectedFileBytes;
  final Map<String, TextEditingController> controllers = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => isLoading = true);

    var user = await Spdb.getUser();

    if (user.userType == UserType.admin) {
      admin = await Spdb.getAdmin();
      isAdmin = true;
    } else {
      employee = await Spdb.getEmployee();
      isAdmin = false;
    }

    if (employee != null) {
      controllers['mobile'] = TextEditingController(
        text: employee!.mobileNumber,
      );
      controllers['address'] = TextEditingController(text: employee!.address);
      controllers['about'] = TextEditingController(text: employee!.about);
      controllers['skills'] = TextEditingController(text: employee!.skills);
      controllers['maritalStatus'] = TextEditingController(
        text: employee!.maritalStatus,
      );
      controllers['name'] = TextEditingController(text: employee!.name);
    } else if (admin != null) {
      controllers['name'] = TextEditingController(text: admin!.name);
      controllers['mobile'] = TextEditingController(text: admin!.mobileNumber);
    }

    setState(() => isLoading = false);
  }

  Future<void> _editAdminProfile({required double width}) async {
    if (admin == null || admin!.uid == null || admin!.uid!.isEmpty) return;

    final result = kIsMobile || width < 1000
        ? await Sheet.showSheet(
            context,
            widget: AdminUpdate(id: admin!.uid!, admin: admin!),
          )
        : await GeneralDialog.showRTLSheet(
            context,
            AdminUpdate(id: admin!.uid!, admin: admin!),
          );

    if (result == true) {
      final latest = await AdminService.getAdmin(uid: admin!.uid!);
      if (latest != null && mounted) {
        final cid = await Spdb.getCid();
        if (cid != null && cid.isNotEmpty) {
          await Spdb.setAdminLogin(model: latest, cid: cid);
        }
        setState(() {
          admin = latest;
        });
      }
    }
  }

  IconData getSectionIcon(String title) {
    switch (title) {
      case "Personal Information":
        return Iconsax.user_square;
      case "Official Information":
        return Iconsax.briefcase;
      case "Contact & Security":
        return Iconsax.shield_tick;
      default:
        return Iconsax.element_3;
    }
  }

  Future<void> _changeProfileImage() async {
    XFile? imageFile;

    if (kIsWeb) {
      // Web: file_picker gives bytes, wrap as XFile (works directly with
      // XFile.readAsBytes() for both display and upload — no dart:io File).
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
    } else if (kIsWindows) {
      // Windows: file picker only
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: 'Select a profile photo',
      );
      if (result == null || result.files.isEmpty) return;
      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;
      imageFile = XFile(pickedPath);
    } else {
      // Mobile: gallery only

      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 65,
      );
      if (pickedImage == null) return;

      final rotated = await FlutterExifRotation.rotateImage(
        path: pickedImage.path,
      );
      imageFile = XFile(rotated.path);
    }

    FlushBar.show(context, "Uploading profile picture...");
    final bytes = await imageFile.readAsBytes();
    setState(() {
      _selectedFile = imageFile;
      _selectedFileBytes = bytes;
    });

    try {
      String downloadUrl;
      if (isAdmin) {
        downloadUrl = await xFileToUploadUrl(
          imageFile,
          StorageFolder.adminProfile,
        );
        final updatedAdmin = admin!.copyWith(profileImageUrl: downloadUrl);
        await AdminService.updateAdmin(
          id: updatedAdmin.uid!,
          data: updatedAdmin,
        );

        String? cid = await Spdb.getCid();
        await Spdb.setAdminLogin(model: updatedAdmin, cid: cid ?? '');

        setState(() => admin = updatedAdmin);
      } else {
        String uid = employee!.uid!;
        final storageRef = FirebaseStorage.instance.ref().child(
          "profile_images/profile_$uid.jpg",
        );
        if (kIsWeb) {
          await storageRef.putData(await imageFile.readAsBytes());
        } else {
          await storageRef.putFile(File(imageFile.path));
        }
        downloadUrl = await storageRef.getDownloadURL();
        final updatedEmployee = employee!.copyWith(
          profileImageUrl: downloadUrl,
          updatedAt: DateTime.now(),
        );

        await EmployeeService.editEmployee(
          uid: updatedEmployee.uid!,
          employee: updatedEmployee,
        );

        String? cid = await Spdb.getCid();
        await Spdb.setEmployeeLogin(
          model: updatedEmployee,
          cid: cid ?? '',
          logoUrl: downloadUrl,
        );

        setState(() => employee = updatedEmployee);
      }

      FlushBar.show(
        context,
        "Profile picture updated successfully",
        isSuccess: true,
      );
    } catch (e) {
      FlushBar.show(
        context,
        "Failed to update profile picture: $e",
        isSuccess: false,
      );
    }
  }

  Future<void> _saveSingleField(String key) async {
    if (employee == null) return;
    String? cid = await Spdb.getCid();
    String newValue = controllers[key]?.text.trim() ?? '';

    try {
      final updatedEmployee = employee!.copyWith(
        name: key == 'name' ? newValue : employee!.name,
        mobileNumber: key == 'mobile' ? newValue : employee!.mobileNumber,
        address: key == 'address' ? newValue : employee!.address,
        about: key == 'about' ? newValue : employee!.about,
        skills: key == 'skills' ? newValue : employee!.skills,
        maritalStatus: key == 'maritalStatus'
            ? newValue
            : employee!.maritalStatus,
        updatedAt: DateTime.now(),
      );

      await EmployeeService.editEmployee(
        uid: updatedEmployee.uid!,
        employee: updatedEmployee,
      );
      await Spdb.setEmployeeLogin(model: updatedEmployee, cid: cid ?? '');

      setState(() {
        employee = updatedEmployee;
        editingField = null;
      });

      FlushBar.show(context, "Information updated", isSuccess: true);
    } catch (e) {
      FlushBar.show(context, "Update failed: $e", isSuccess: false);
    }
  }

  Future<void> _removeProfileImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Profile Photo"),
        content: const Text("Are you sure you want to remove this photo?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    FlushBar.show(context, "Removing profile picture...");

    try {
      if (!isAdmin) {
        await EmployeeService.deleteEmployeeImage(uid: employee!.uid!);
        final updated = employee!.copyWith(profileImageUrl: '');
        await Spdb.setEmployeeLogin(
          model: updated,
          cid: await Spdb.getCid() ?? '',
        );
        setState(() {
          employee = updated;
          _selectedFile = null;
          _selectedFileBytes = null;
        });
      } else {
        await AdminService.deleteAdminProfileImage(uid: admin!.uid!);
        final updated = admin!.copyWith(profileImageUrl: '');
        setState(() => admin = updated);
      }

      FlushBar.show(context, "Profile removed", isSuccess: true);
    } catch (e) {
      FlushBar.show(context, "Remove failed: $e", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: Back(color: Theme.of(context).colorScheme.onSurface),
        title: Text(
          "My Profile",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Edit Profile',
              onPressed: () => _editAdminProfile(width: width),
              icon: Icon(
                Iconsax.edit,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: WaitingLoading())
          : LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 1000;
                return SingleChildScrollView(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      padding: EdgeInsets.all(isDesktop ? 40 : 16),
                      child: isDesktop
                          ? _buildDesktopLayout()
                          : _buildMobileLayout(),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 350,
          child: Column(
            children: [
              _buildStickyProfileCard(),
              const SizedBox(height: 24),
              _buildStatsCard(),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            children: [
              _buildEmployeeGrid(2),
              const SizedBox(height: 40),
              _buildFooter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildProfileHeader(),
        const SizedBox(height: 24),
        _buildEmployeeGrid(1),
        const SizedBox(height: 40),
        _buildFooter(),
      ],
    );
  }

  Widget _buildStickyProfileCard() {
    final name = isAdmin ? admin?.name ?? "-" : employee?.name ?? "-";
    final role = isAdmin
        ? "System Administrator"
        : (CacheService.designationByUid(employee?.designation ?? '')?.name ??
              "Employee");
    final image = isAdmin ? admin?.profileImageUrl : employee?.profileImageUrl;

    // Use locally captured file if available (shows immediately after capture)
    final ImageProvider? localImageProvider = _selectedFileBytes != null
        ? MemoryImage(_selectedFileBytes!)
        : null;
    final ImageProvider? networkImageProvider =
        (image != null && image.isNotEmpty) ? NetworkImage(image) : null;
    final ImageProvider? displayImage =
        localImageProvider ?? networkImageProvider;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: (image != null && image.isNotEmpty)
                    ? () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: EdgeInsets.zero,
                            child: SafeArea(
                              child: Stack(
                                children: [
                                  Center(
                                    child: InteractiveViewer(
                                      child: CachedNetworkImage(
                                        imageUrl: image,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                          Row(
                                            children: [
                                              if (image.isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(
                                                    Iconsax.trash,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () async {
                                                    Navigator.pop(context);
                                                    await _removeProfileImage();
                                                  },
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 20,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Text(
                                        "Profile Photo",
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      width: 4,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 70,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    backgroundImage: displayImage,
                    child: displayImage == null
                        ? Text(
                            name.trim().isNotEmpty
                                ? name.trim()[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              Material(
                color: Theme.of(context).colorScheme.secondary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _changeProfileImage,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Icon(
                      kIsWindows ? Icons.upload_file_rounded : Iconsax.image,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            role,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildInfoTile(
            Iconsax.personalcard,
            "Employee ID",
            employee?.employeeId ?? "N/A",
          ),
          _buildInfoTile(
            Iconsax.sms,
            "Corporate Email",
            employee?.email ?? admin?.email ?? "-",
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Status", "Active", AppColors.success),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          _buildStatItem(
            "Joined",
            employee?.dateOfJoining.formatDate.split(' ').first ?? "-",
            Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return _buildStickyProfileCard();
  }

  Widget _buildEmployeeGrid(int crossAxisCount) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _buildResponsiveSection("Personal Information", [
          _buildDataPoint("Full Name", "name", employee?.name),
          _buildDataPoint(
            "Gender",
            "gender",
            employee?.gender,
            editable: false,
          ),
          _buildDataPoint(
            "Date of Birth",
            "dob",
            employee?.dateOfBirth?.formatDate,
            editable: false,
          ),
          _buildDataPoint(
            "Marital Status",
            "maritalStatus",
            employee?.maritalStatus,
          ),
          _buildDataPoint("About Me", "about", employee?.about),
          _buildDataPoint("Special Skills", "skills", employee?.skills),
        ], crossAxisCount),
        _buildResponsiveSection("Official Information", [
          _buildDataPoint(
            "Employment",
            "employeeType",
            employee?.employeeType,
            editable: false,
          ),
          _buildDataPoint(
            "Role Type",
            "role",
            CacheService.roleByUid(employee?.role ?? '')?.name ?? '',
            editable: false,
          ),
          _buildDataPoint(
            "Department",
            "dept",
            (employee?.department ?? [])
                .map((u) => CacheService.departmentByUid(u)?.name ?? '')
                .join(', '),
            editable: false,
          ),
          _buildDataPoint(
            "Manager",
            "manager",
            (employee?.reportingTo ?? [])
                .map((u) => CacheService.getUserByUid(u)?.name ?? '')
                .join(', '),
            editable: false,
          ),
        ], crossAxisCount),
        _buildResponsiveSection("Contact & Security", [
          _buildDataPoint("Phone Number", "mobile", employee?.mobileNumber),
          _buildDataPoint("Residential Address", "address", employee?.address),
          _buildDataPoint(
            "Email Notifications",
            "notif",
            employee?.receiveEmailNotifications == true
                ? "Subscribed"
                : "Muted",
            editable: false,
          ),
        ], crossAxisCount),
      ],
    );
  }

  Widget _buildResponsiveSection(
    String title,
    List<Widget> items,
    int gridCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = gridCount == 1
            ? double.infinity
            : (constraints.maxWidth / gridCount) - 12;
        return Container(
          width: width,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
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
                      ).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      getSectionIcon(title),
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ...items,
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataPoint(
    String label,
    String key,
    String? value, {
    bool editable = true,
  }) {
    bool isEditing = editingField == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                if (isEditing)
                  TextField(
                    controller: controllers[key],
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                  )
                else
                  Text(
                    value != null && value.isNotEmpty ? value : "Not Specified",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: (value == null || value.isEmpty)
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          ),
          if (editable && !isAdmin)
            IconButton(
              onPressed: () {
                if (isEditing) {
                  _saveSingleField(key);
                } else {
                  setState(() => editingField = key);
                }
              },
              icon: Icon(
                isEditing ? Iconsax.tick_circle : Iconsax.edit,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: Column(
          children: [
            Text(
              "Data synchronized with secure server",
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Security Patch: ${AppPackageInfo.version} • ${DateTime.now().monthYearFormat}",
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
