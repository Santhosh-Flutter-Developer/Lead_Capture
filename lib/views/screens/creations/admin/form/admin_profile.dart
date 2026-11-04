import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class AdminProfile extends StatefulWidget {
  final AdminModel admin;
  const AdminProfile({super.key, required this.admin});

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  PermissionModel? _permissions;
  late AdminModel _admin;
  final ScrollController _vScrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    _admin = widget.admin;
    _loadPermissions();
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Admin');
    if (mounted) setState(() {});
  }

  Future<void> _openEdit({required double width}) async {
    final uid = _admin.uid;
    if (uid == null || uid.isEmpty) {
      FlushBar.show(
        context,
        'Unable to edit this admin profile',
        isSuccess: false,
      );
      return;
    }

    final result = kIsMobile || width < 1000
        ? await Sheet.showSheet(
            context,
            widget: AdminUpdate(id: uid, admin: _admin),
          )
        : await GeneralDialog.showRTLSheet(
            context,
            AdminUpdate(id: uid, admin: _admin),
          );

    if (result != true) return;

    try {
      final latest = await AdminService.getAdmin(uid: uid);
      if (latest != null && mounted) {
        setState(() {
          _admin = latest;
        });
      }
    } catch (_) {}
  }

  Future<bool> _canEditAdmin() async {
    final currentUid = await Spdb.getUid();
    if (_admin.uid != null && _admin.uid == currentUid) return true;
    return _permissions?.canEdit ?? false;
  }

  Future<void> _changeProfileImage() async {
    final uid = _admin.uid;
    if (uid == null || uid.isEmpty) return;

    // Use PickImage.pickFromGallery() instead of instantiating ImagePicker()
    // directly. On web, ImagePicker().pickImage(imageQuality: ...) makes the
    // plugin resize the image on a canvas and hand back an XFile backed by a
    // blob: object URL. xFileToUploadUrl() -> xfile.readAsBytes() then fetches
    // that blob URL, but the browser can revoke it first (this happens very
    // reliably in InPrivate/Incognito windows), causing:
    // "Exception: Could not load Blob from its URL. Has it been revoked?"
    // PickImage.pickFromGallery() avoids this entirely on web by using
    // file_picker with withData: true, which returns the raw bytes directly
    // (via XFile.fromData) with no intermediate blob URL to revoke.
    final pickedImage = await PickImage.pickFromGallery();

    if (pickedImage == null) return;
    FlushBar.show(context, "Uploading profile picture...");

    try {
      String downloadUrl = await xFileToUploadUrl(
        pickedImage,
        StorageFolder.adminProfile,
      );

      final updatedAdmin = _admin.copyWith(profileImageUrl: downloadUrl);
      await AdminService.updateAdmin(id: uid, data: updatedAdmin);

      // Update local session if this is the logged-in admin
      final currentUid = await Spdb.getUid();
      final cid = await Spdb.getCid();
      if (currentUid == uid && cid != null) {
        await Spdb.setAdminLogin(model: updatedAdmin, cid: cid);
      }

      if (mounted) {
        setState(() => _admin = updatedAdmin);
        FlushBar.show(
          context,
          "Profile picture updated successfully",
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        FlushBar.show(
          context,
          "Failed to update profile picture: $e",
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _removeProfileImage() async {
    final uid = _admin.uid;
    if (uid == null || uid.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove Profile Photo"),
        content: const Text("Are you sure you want to remove this photo?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    FlushBar.show(context, "Removing profile picture...");

    try {
      await AdminService.deleteAdminProfileImage(uid: uid);

      final updated = _admin.copyWith(profileImageUrl: '');

      // Update local session if this is the logged-in admin
      final currentUid = await Spdb.getUid();
      final cid = await Spdb.getCid();
      if (currentUid == uid && cid != null) {
        await Spdb.setAdminLogin(model: updated, cid: cid);
      }

      if (mounted) {
        setState(() => _admin = updated);
        FlushBar.show(context, "Profile removed", isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        FlushBar.show(context, "Remove failed: $e", isSuccess: false);
      }
    }
  }

  void _viewFullImage(String imageUrl, {required bool canEdit}) {
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
                    imageUrl: imageUrl,
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
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      if (canEdit)
                        IconButton(
                          icon: const Icon(Iconsax.trash, color: Colors.red),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _removeProfileImage();
                          },
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
                      color: Colors.white.withValues(alpha: 0.8),
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

  Widget _buildHeader(BuildContext context, bool canEdit, double width) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Back(color: Colors.white),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Iconsax.shield_tick,
                color: AppColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _admin.isActive
                        ? 'Active administrator'
                        : 'Inactive administrator',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit)
              IconButton(
                onPressed: () => _openEdit(width: width),
                tooltip: 'Edit Admin',
                icon: const Icon(Iconsax.edit, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return FutureBuilder<bool>(
      future: _canEditAdmin(),
      builder: (context, snapshot) {
        final canEdit = snapshot.data ?? false;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, canEdit, width),
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildProfileCard(context, canEdit),
                          const SizedBox(height: 20),
                          _buildDetailsCard(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, bool canEdit) {
    final image = _admin.profileImageUrl;
    final hasImage = image != null && image.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
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
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: hasImage
                    ? () => _viewFullImage(image, canEdit: canEdit)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _brandGradient,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    backgroundImage: hasImage
                        ? NetworkImage(image)
                        : const NetworkImage(AppStrings.emptyProfilePhotoUrl)
                              as ImageProvider,
                  ),
                ),
              ),
              if (canEdit)
                Container(
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
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _changeProfileImage,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(9.0),
                        child: Icon(
                          Iconsax.camera,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            _admin.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _admin.isActive ? AppColors.success : AppColors.danger,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _admin.isActive ? Iconsax.tick_circle : Iconsax.close_circle,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  _admin.isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                  Iconsax.personalcard,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Admin Details",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "Contact details and account status",
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
          const SizedBox(height: 8),

          _detailRow(
            context: context,
            icon: Iconsax.sms,
            accentColor: AppColors.secondary,
            label: 'Email',
            value: _admin.email,
          ),
          _divider(),

          _detailRow(
            context: context,
            icon: Iconsax.call,
            accentColor: AppColors.orange,
            label: 'Mobile Number',
            value: _admin.mobileNumber.isEmpty ? '-' : _admin.mobileNumber,
          ),
          _divider(),

          _detailRow(
            context: context,
            icon: Iconsax.shield_tick,
            accentColor: _admin.isActive ? AppColors.success : AppColors.danger,
            label: 'Status',
            value: _admin.isActive ? 'Active' : 'Inactive',
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: accentColor),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: AppColors.grey200),
    );
  }
}
