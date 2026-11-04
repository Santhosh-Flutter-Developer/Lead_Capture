import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class AdminUpdate extends StatefulWidget {
  final AdminModel admin;
  final String id;

  const AdminUpdate({super.key, required this.admin, required this.id});

  @override
  State<AdminUpdate> createState() => _AdminUpdateState();
}

class _AdminUpdateState extends State<AdminUpdate> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();

  XFile? _newProfileImage;
  Uint8List? _newProfileImageBytes;
  String? _existingProfileUrl;

  bool _passwordVisible = false;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();

    _nameController.text = widget.admin.name;
    _emailController.text = widget.admin.email;
    _passwordController.text = widget.admin.password;
    _mobileController.text = widget.admin.mobileNumber;
    _existingProfileUrl = widget.admin.profileImageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _vScrollController.dispose();
    super.dispose();
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
            child: const Icon(Iconsax.edit, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update Admin",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Update this administrator's account details",
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
    final Color badgeColor =
        accentColor ?? Theme.of(context).colorScheme.primary;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: Padding(
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
                    child: Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildSectionCard(
                              icon: Iconsax.gallery,
                              title: "Profile Picture",
                              subtitle:
                                  "Update this administrator's profile picture",
                              child: Center(child: _buildProfileUploader()),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              icon: Iconsax.personalcard,
                              accentColor: AppColors.secondary,
                              title: "Admin Details",
                              subtitle: "Account name, login and contact details",
                              child: LayoutBuilder(
                                builder: (context, constraints) =>
                                    _buildAdminDetails(constraints, 2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                  onTap: _updateAdmin,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.edit, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          "Update",
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

  // ADMIN DETAILS FIELDS
  Widget _buildAdminDetails(BoxConstraints constraints, int gridCount) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >= (minColumnWidth * 3 + horizontalSpacing * (3 - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (3 - 1)) / 3
        : currentWidth;

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Name",
            controller: _nameController,
            isRequired: true,
            prefixIcon: const Icon(Iconsax.user, size: 18),
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Name is required";
              }
              if (value.length < 3) return "Name must be at least 3 characters";
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Email",
            controller: _emailController,
            isRequired: true,
            prefixIcon: const Icon(Iconsax.sms, size: 18),
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Email is required";
              }
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return "Enter a valid email address";
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Password",
            controller: _passwordController,
            isRequired: true,
            obsecureText: !_passwordVisible,
            prefixIcon: const Icon(Iconsax.lock, size: 18),
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Password is required";
              }
              if (value.length < 6) {
                return "Password must be at least 6 characters";
              }
              return null;
            },
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
            label: "Mobile Number",
            controller: _mobileController,
            isRequired: true,
            prefixIcon: const Icon(Iconsax.mobile, size: 18),
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Mobile number is required";
              }
              final mobileRegex = RegExp(r'^[0-9]{10}$');
              if (!mobileRegex.hasMatch(value.trim())) {
                return "Enter a valid 10-digit mobile number";
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // PROFILE IMAGE UPLOAD — circular gradient-ring avatar, matching the
  // Employee create/edit uploader style, with a remove/replace badge.
  Widget _buildProfileUploader() {
    final bool hasImage =
        _newProfileImage != null ||
        (_existingProfileUrl != null && _existingProfileUrl!.isNotEmpty);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              final picked = await PickImage.selectImage(context);
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              setState(() {
                _newProfileImage = picked;
                _newProfileImageBytes = bytes;
                _existingProfileUrl = null;
              });
            },
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
                      child: _newProfileImageBytes != null
                          ? Image.memory(
                              _newProfileImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : (_existingProfileUrl != null &&
                                _existingProfileUrl!.isNotEmpty)
                          ? Image.network(
                              _existingProfileUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Iconsax.gallery_slash, size: 32),
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
                        _newProfileImage = null;
                        _newProfileImageBytes = null;
                        _existingProfileUrl = null;
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
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
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
                    child: const Icon(
                      Iconsax.camera,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasImage ? 'Tap to change photo' : 'Tap to add photo',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      futureLoading(context);

      String? newImageUrl = _existingProfileUrl;

      if (_newProfileImage != null) {
        newImageUrl = await xFileToUploadUrl(
          _newProfileImage!,
          StorageFolder.adminProfile,
        );
      }

      AdminModel adminModel = AdminModel(
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        password: _passwordController.text,
        mobileNumber: _mobileController.text.trim(),
        profileImageUrl: newImageUrl,
        createdBy: await Spdb.getUser(),
      );

      await AdminService.updateAdmin(id: widget.id, data: adminModel);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, true);
      FlushBar.show(context, "Admin updated successfully", isSuccess: true);
    } catch (e, st) {
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
