import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/services/services.dart';
part 'mobile_main_screen.dart';
part 'desktop_main_screen.dart';

class MainScreen extends StatelessWidget {
  final bool isAdmin;
  final String? selectedMenu;
  final String? selectedChatUid;
  const MainScreen({
    super.key,
    required this.isAdmin,
    this.selectedMenu,
    this.selectedChatUid,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (kIsMobile || width < 1000) {
      return MobileMainScreen(isAdmin: isAdmin);
    } else {
      return DesktopMainScreen(
        isAdmin: isAdmin,
        selectedMenu: selectedMenu,
        selectedChatUid: selectedChatUid,
      );
    }
  }
}