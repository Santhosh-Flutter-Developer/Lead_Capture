import 'dart:typed_data';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class AdminCreate extends StatefulWidget {
  const AdminCreate({super.key});

  @override
  State<AdminCreate> createState() => _AdminCreateState();
}

class _AdminCreateState extends State<AdminCreate> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  XFile? _profileImage;

  bool _passwordVisible = false;

  late Future _future;

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    try {} catch (e, st) {
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 10),
        child: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            } else if (snapshot.hasError) {
              return ErrorDisplay(error: snapshot.error.toString());
            } else {
              return Center(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      FormWidgets.buildHeader(
                        context: context,
                        title: "Create Admin",
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: "Admin Details",
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildAdminDetails(constraints, 2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: "Profile Picture",
                        child: Center(
                          child: _buildProfileImageUploaded("Upload Profile"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
      bottomNavigationBar: FormWidgets.buildBottomBar(
        context: context,
        onSubmit: _submitForm,
        isEdit: false,
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.grey300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: AppColors.grey300),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

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
            label: "Full Name",
            controller: _nameController,
            hintText: "Enter full name",
            isRequired: true,
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Full name is required";
              }
              if (value.trim().length < 3) {
                return "Name must be at least 3 characters";
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Email",
            controller: _emailController,
            hintText: "Enter email",
            isRequired: true,
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Email is required";
              }
              final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
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
            hintText: "Enter password",
            isRequired: true,
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

            valid: (value) {
              if (value == null || value.isEmpty) {
                return "Password is required";
              }
              if (value.length < 6) {
                return "Password must be at least 6 characters";
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: "Mobile Number",
            controller: _mobileController,
            hintText: "Enter mobile number",
            isRequired: true,
            valid: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Mobile number is required";
              }
              if (value.length != 10) {
                return "Mobile number must be 10 digits";
              }
              if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                return "Only digits allowed";
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImageUploaded(String label) {
    if (_profileImage != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 140,
              width: 140,
              child: FutureBuilder<Uint8List>(
                future: _profileImage!.readAsBytes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return Image.memory(
                    snapshot.data!,
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () async {
                final result = await PickImage.selectImage(context);
                if (result != null) setState(() => _profileImage = result);
              },
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () async {
        final result = await PickImage.selectImage(context);
        if (result != null) setState(() => _profileImage = result);
      },
      child: DottedBorder(
        options: RectDottedBorderOptions(),
        child: Container(
          height: 140,
          width: 140,
          decoration: const BoxDecoration(
            color: AppColors.grey200,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.gallery, color: AppColors.grey700),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.grey700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      futureLoading(context);

      String? profileUrl;
      if (_profileImage != null) {
        profileUrl = await xFileToUploadUrl(
          _profileImage!,
          StorageFolder.adminProfile,
        );
      }

      AdminModel admin = AdminModel(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        mobileNumber: _mobileController.text.trim(),
        profileImageUrl: profileUrl,
        createdBy: await Spdb.getUser(),
      );

      await AdminService.createAdmin(admin: admin);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, true);
      FlushBar.show(context, "Admin created successfully", isSuccess: true);
    } catch (e, st) {
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
