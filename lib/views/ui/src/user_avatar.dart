import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '/constants/constants.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';

class UserAvatar extends StatefulWidget {
  final UserDataModel userData;
  final double size;
  final bool showCrown;

  const UserAvatar({
    super.key,
    required this.userData,
    this.size = 32,
    this.showCrown = true,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isHoveringAvatar = false;
  bool _isHoveringCard = false;

  void _showHoverCard() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(
            widget.size + 12,
            -40,
          ), // Positioned to the right of avatar
          child: MouseRegion(
            onEnter: (_) {
              _isHoveringCard = true;
            },
            onExit: (_) {
              _isHoveringCard = false;
              _hideHoverCard();
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: child,
                  ),
                );
              },
              child: _buildInfoCard(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideHoverCard() {
    // Small delay to check if mouse moved to the card or back to avatar
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (!_isHoveringAvatar && !_isHoveringCard) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  Widget _buildInfoCard() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FutureBuilder(
          future: _fetchUserDetails(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final dynamic model = snapshot.data;
            final String name = widget.userData.name;
            final String role = _getRoleText(model);
            final String? email = model?.email;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child:
                          widget.userData.profilePic != null &&
                              widget.userData.profilePic!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.userData.profilePic!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,

                              errorWidget: (context, url, error) {
                                return Container(
                                  color: const Color(0xFF2563EB),
                                  alignment: Alignment.center,
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: const Color(0xFF2563EB),
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            role,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (email != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  _buildMetaRow(Iconsax.sms, email),
                  if (model is EmployeeModel && model.mobileNumber.isNotEmpty)
                    _buildMetaRow(Iconsax.call, model.mobileNumber),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<dynamic> _fetchUserDetails() async {
    if (widget.userData.userType == UserType.employee) {
      return await EmployeeService.getEmployee(uid: widget.userData.uid);
    } else if (widget.userData.userType == UserType.admin) {
      return await AdminService.getAdmin(uid: widget.userData.uid);
    }
    return null;
  }

  String _getRoleText(dynamic model) {
    if (model is AdminModel) return "ADMINISTRATOR";
    if (model is EmployeeModel) {
      return CacheService.designationByUid(
            model.designation,
          )?.name.toUpperCase() ??
          "EMPLOYEE";
    }
    return "USER";
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          _isHoveringAvatar = true;
          _showHoverCard();
        },
        onExit: (_) {
          _isHoveringAvatar = false;
          _hideHoverCard();
        },
        child: Tooltip(
          message: widget.userData.name,
          child: InkWell(
            onTap: () async {
              var chatId = await ChatService.getChatUid(widget.userData.uid);
              debugPrint("the chat id on getchat id $chatId");
              var currentUserUid = await Spdb.getUid();
              if (chatId != null && currentUserUid != null) {
                if (!mounted) return;
                GeneralDialog.showRTLSheet(
                  context,
                  ChatListing(
                    currentUserUid: currentUserUid,
                    selectedChatUid: chatId,
                  ),
                );
              }
            },
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        color: LetterColors.getColor(
                          widget.userData.name.isNotEmpty
                              ? widget.userData.name[0]
                              : '?',
                        ),
                      ),
                      child:
                          widget.userData.profilePic != null &&
                              widget.userData.profilePic!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.userData.profilePic!,
                              fit: BoxFit.cover,
                              width: widget.size,
                              height: widget.size,

                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: AppColors.grey300,
                                highlightColor: AppColors.grey100,
                                child: Container(
                                  width: widget.size,
                                  height: widget.size,
                                  color: Colors.white,
                                ),
                              ),

                              errorWidget: (context, url, error) {
                                return Container(
                                  width: widget.size,
                                  height: widget.size,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: LetterColors.getColor(
                                      widget.userData.name.isNotEmpty
                                          ? widget.userData.name[0]
                                          : '?',
                                    ),
                                  ),
                                  child: Text(
                                    _getInitials(widget.userData.name),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: widget.size * 0.4,
                                        ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                _getInitials(widget.userData.name),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: widget.size * 0.4,
                                    ),
                              ),
                            ),
                    ),
                  ),
                  if (widget.userData.userType == UserType.admin &&
                      widget.showCrown)
                    Positioned(
                      top: -widget.size * 0.1,
                      right: -widget.size * 0.1,
                      child: Icon(
                        Iconsax.crown_15,
                        color: const Color(0xFFFFC107),
                        size: widget.size * 0.45,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
