import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    return Scaffold(backgroundColor: AppColors.white, body: _splashBody());
  }

  Widget _splashBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Image(
            image: AssetImage(ImageAssets.logoTransparent),
            height: 140,
            width: 140,
          ),
          const SizedBox(height: 10),
          LoadingAnimationWidget.progressiveDots(
            color: AppColors.primary,
            size: 40,
          ),
        ],
      ),
    );
  }
}
